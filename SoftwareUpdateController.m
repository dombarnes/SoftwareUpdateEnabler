/*
 * Project:     SoftwareUpdateEnabler
 * File:        SoftwareUpdateController.m
 * Author:      Andrew Wellington
 *
 * License:
 * Copyright (C) 2005-2009 Andrew Wellington.
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 
 * 1. Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SoftwareUpdateController.h"
#import "SoftwareUpdatePreferences.h"

#import "NSApplication+SystemVersion.h"

static NSString *SUEUpdateServerKey = @"updateServer";
static NSString *SUEStatusKey = @"status";

static NSString *SUERecentServers = @"SUERecentServers";
static NSString *SUERecentServersName = @"SUERecentServersName";
static NSString *SUERecentServersDate = @"SUERecentServersDate";
static NSString *SUERecentServersCount = @"SUERecentServersCount";

static NSString *SUECatalogInfoPlist = @"CatalogInfo";
static NSString *SUECatalogFallbackKey = @"Fallback";
static NSString *SUECatalogNamesKey = @"CatalogNames";
static NSString *SUECatalogPortsKey = @"ServerPorts";

static NSString *SUEDefaultCatalogName = @"index.sucatalog";

static CFStringRef SUECatalogPreferencesKey = CFSTR("CatalogURL");
static CFStringRef SUEPreferencesDomain = CFSTR("com.apple.SoftwareUpdate");


@interface SoftwareUpdateController (PRIVATE)
- (void)updatePreferencesOnDisk;
- (NSString *)currentUpdateServer;
- (NSArray *)calculateServerURLFromInput:(NSString *)input;
- (NSString *)stripDoubleSlashes:(NSString *)url;
- (void)showCantVerifySheet;
- (void)tryNextURL;
- (void)removeOldUpdateServers;
@end

@implementation SoftwareUpdateController
- (id)init
{
	self = [super init];
	if (!self)
		return self;
	
	updateServer = [[self currentUpdateServer] retain];
	status = nil;
	testURLs = nil;
	startSave = nil;
	
	return self;
}


- (IBAction)revertToApple:(id)sender
{
	[self setValue:nil forKey:SUEUpdateServerKey];
	[self updatePreferencesOnDisk];
}

- (IBAction)save:(id)sender
{
	if (URLconnection) {
		[URLconnection cancel];
		[URLconnection release];
		URLconnection = nil;
		[testURLs release];
		testURLs = nil;
		[startSave release];
		startSave = nil;
	}
	
	startSave = [[NSDate date] retain];
	
	if (updateServer == nil || [updateServer isEqualToString:@""]) {
		[self setValue:nil forKey:SUEUpdateServerKey];
		[self updatePreferencesOnDisk];
		return;
	}
    
	
	/* verify server */
	[self setValue:NSLocalizedString(@"Verifying Server...", @"Status when checking server is OK") forKey:SUEStatusKey];
	
    testURLs = [[self calculateServerURLFromInput:updateServer] mutableCopy];
    [self tryNextURL];
}

- (void)tryNextURL
{
	NSMutableURLRequest *request;

    if (URLconnection) {
        [URLconnection release];
        URLconnection = nil;
    }

    if ([testURLs count] == 0) {
        NSLog(@"Failed to find good SU server");
        return;
    }

    NSLog(@"Checking %@...", [testURLs objectAtIndex:0]);
    
    testURL = [[testURLs objectAtIndex:0] retain];
    [testURLs removeObjectAtIndex:0];

    request = [NSMutableURLRequest requestWithURL:testURL];
    [request setTimeoutInterval:5.0];
	URLconnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];

}

- (void)updatePreferencesOnDisk
{
	NSMutableArray *recentServers;
	int recentServersCount;
	NSEnumerator *recentServersEnum;
	NSDictionary *recentServer;
	BOOL recentServerShouldAdd = YES;
	
    [self removeOldUpdateServers];
    
	/* save settings */
	[self setValue:NSLocalizedString(@"Saving Settings...", @"Status when saving settings") forKey:SUEStatusKey];
    if (![SoftwareUpdatePreferences updateCatalogURL:updateServer]) {
        NSAlert *alert;
		
		[self setValue:NSLocalizedString(@"Failed to save settings", @"Status message when settings can't be saved") forKey:SUEStatusKey];
		
		alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Could not write settings to disk", @"Error message if preferences synchronise fails")
								defaultButton:NSLocalizedString(@"Cancel", @"Default button if we couldn't save")
							  alternateButton:NSLocalizedString(@"Try Again", @"Alternate button if we couldn't save")
								  otherButton:nil
					informativeTextWithFormat:NSLocalizedString(@"Check that you have permission to write these settings and try again.", @"Informative text when preferences syncrhonise fails")];
		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert beginSheetModalForWindow:mainWindow
						  modalDelegate:self
						 didEndSelector:@selector(cantSaveSheetDidReturn:returnCode:contextInfo:)
							contextInfo:nil];
		
		[startSave release];
		startSave = nil;
    }
        
	/* Update recent server list */
	if (updateServer != nil && ![updateServer isEqualToString:@""]) {
		recentServers = [[NSUserDefaults standardUserDefaults] objectForKey:SUERecentServers];
		if (recentServers == nil || ![recentServers isKindOfClass:[NSArray class]]) {
			recentServers = [[NSMutableArray alloc] init];
		} else {
			recentServers = [recentServers mutableCopy];
		}
		
		recentServersCount = [[NSUserDefaults standardUserDefaults] integerForKey:SUERecentServersCount];
		if (recentServersCount <= 1)
			recentServersCount = 5;
		
		recentServersEnum = [recentServers objectEnumerator];
		while ((recentServer = [recentServersEnum nextObject])) {
			if (![recentServer isKindOfClass:[NSDictionary class]])
				continue;
			
			if ([[recentServer objectForKey:SUERecentServersName] isEqualToString: updateServer])
			{
				recentServerShouldAdd = NO;
				break;
			}
		}
		
		if (recentServerShouldAdd) {
			if ([recentServers count] >= recentServersCount)
				[recentServers removeObjectAtIndex: [recentServers count] - 1];
			
			[recentServers insertObject:[NSDictionary dictionaryWithObjectsAndKeys:
											updateServer, SUERecentServersName,
											[NSDate date], SUERecentServersDate,
											nil, nil]
								atIndex:0];
		} else {
			[recentServers removeObject:recentServer];
			[recentServers insertObject:recentServer atIndex:0];
		}
		
		[[NSUserDefaults standardUserDefaults] setObject:recentServers forKey:SUERecentServers];
		[[NSUserDefaults standardUserDefaults] synchronize];
	
	}
		
	/* and ensure we don't disappear the save info too quick */
	if ([startSave timeIntervalSinceNow] < -2)
		[self performSelector:@selector(clearStatus:) withObject:nil afterDelay:2.0 - abs([startSave timeIntervalSinceNow])];
	else
		[self performSelector:@selector(clearStatus:) withObject:nil afterDelay:0.0];

	[startSave release];
	startSave = nil;
}

- (NSString *)currentUpdateServer
{
	CFPropertyListRef prefsProperty;
	NSString *server;
	
        /* All Users on This Computer */
        prefsProperty = CFPreferencesCopyValue (SUECatalogPreferencesKey,
                                                SUEPreferencesDomain,
                                                kCFPreferencesAnyUser,
                                                kCFPreferencesCurrentHost);			
	if ([(NSObject *)prefsProperty isKindOfClass:[NSString class]])
		server = (NSString *)prefsProperty;
	else
		server = nil;
	
	return [server autorelease];
}


- (void)clearStatus:(id)sender
{
	[self setValue:nil forKey:SUEStatusKey];
}

- (void)cantVerifySheetDidReturn:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
	[[alert window] orderOut: self];
	
	if (returnCode == NSAlertDefaultReturn)
		[self setValue:nil forKey:SUEStatusKey];
	else
		[self updatePreferencesOnDisk];
}

- (void)cantSaveSheetDidReturn:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
	[[alert window] orderOut: self];
	
	if (returnCode == NSAlertDefaultReturn)
		[self setValue:nil forKey:SUEStatusKey];
	else
		[self updatePreferencesOnDisk];
}

- (void)showCantVerifySheet
{
	NSAlert *alert;
	alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Could not verify that server is running Software Update", @"Error message if we can't load catalog from server")
							defaultButton:NSLocalizedString(@"Don't Save", @"Default button for no catalog found")
						  alternateButton:NSLocalizedString(@"Save Anyway", @"Alternate button for no catalog found")
							  otherButton:nil
				informativeTextWithFormat:NSLocalizedString(@"The server given may not be running a Software Update service. Please verify the information you entered before saving.", @"Informative text when we can't load catalog from the server")];
	[alert setAlertStyle:NSInformationalAlertStyle];
	[alert beginSheetModalForWindow:mainWindow
					  modalDelegate:self
					 didEndSelector:@selector(cantVerifySheetDidReturn:returnCode:contextInfo:)
						contextInfo:nil];
}

- (void)removeOldUpdateServers
{
    CFPreferencesSetValue(SUECatalogPreferencesKey,
                          NULL,
                          SUEPreferencesDomain,
                          kCFPreferencesCurrentUser,
                          kCFPreferencesCurrentHost);
    CFPreferencesSynchronize (SUEPreferencesDomain, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
    CFPreferencesSetValue(SUECatalogPreferencesKey,
                          NULL,
                          SUEPreferencesDomain,
                          kCFPreferencesCurrentUser,
                          kCFPreferencesAnyHost);
    CFPreferencesSynchronize (SUEPreferencesDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
}

#pragma mark Server URL Calculation
- (NSArray *)catalogNamesForSystem {
    NSDictionary *catalogPlist;
    NSDictionary *catalogLookupTable;
    unsigned systemMajor, systemMinor, systemBugFix;
    NSString *systemVersion;
    NSArray *catalogNames;
    
    catalogPlist = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:SUECatalogInfoPlist ofType:@"plist"]];
    catalogLookupTable = [catalogPlist objectForKey:SUECatalogNamesKey];
    [[NSApplication sharedApplication] SUE_getSystemVersionMajor:&systemMajor minor:&systemMinor bugFix:&systemBugFix];
    systemVersion = [NSString stringWithFormat:@"%u.%u", systemMajor, systemMinor];
    
    catalogNames = [catalogLookupTable objectForKey:systemVersion];
    if (!catalogNames || ![catalogNames isKindOfClass:[NSArray class]])
        catalogNames = [catalogLookupTable objectForKey:SUECatalogFallbackKey];
    if (!catalogNames || ![catalogNames isKindOfClass:[NSArray class]])
        catalogNames = [NSArray arrayWithObject:SUEDefaultCatalogName];
    
    return catalogNames;
}

- (NSArray *)catalogPortsForSystem {
    NSDictionary *catalogPlist;
    NSDictionary *catalogLookupTable;
    unsigned systemMajor, systemMinor, systemBugFix;
    NSString *systemVersion;
    NSArray *catalogNames;
    
    catalogPlist = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:SUECatalogInfoPlist ofType:@"plist"]];
    catalogLookupTable = [catalogPlist objectForKey:SUECatalogPortsKey];
    [[NSApplication sharedApplication] SUE_getSystemVersionMajor:&systemMajor minor:&systemMinor bugFix:&systemBugFix];
    systemVersion = [NSString stringWithFormat:@"%u.%u", systemMajor, systemMinor];
    
    catalogNames = [catalogLookupTable objectForKey:systemVersion];
    if (!catalogNames || ![catalogNames isKindOfClass:[NSArray class]])
        catalogNames = [catalogLookupTable objectForKey:SUECatalogFallbackKey];
    if (!catalogNames || ![catalogNames isKindOfClass:[NSArray class]])
        catalogNames = [NSArray arrayWithObject:SUEDefaultCatalogName];
    
    
    return catalogNames;
}

- (NSArray *)calculateServerURLFromInput:(NSString *)input
{
    NSArray *catalogNames = [self catalogNamesForSystem];
    NSArray *catalogPorts = [self catalogPortsForSystem];

    NSEnumerator *catalogNameEnumerator;
    NSEnumerator *catalogPortEnumerator;
    
    NSString *catalogName;
    NSNumber *catalogPort;

    NSMutableArray *urlList = [[NSMutableArray alloc] init];
    
    NSString *inputWorking;
    NSString *host;
    NSNumber *port;
    NSString *path;
    NSString *scheme;
    
    /* Try to work out what the user has given us */
    inputWorking = input;
    NSRange range;
    
    /* Look for a URL scheme */
    range = [inputWorking rangeOfString:@"://"];
    if (range.location != NSNotFound) {
        scheme = [inputWorking substringToIndex:range.location];
        inputWorking = [inputWorking substringFromIndex:range.location + [@"://" length]];
    } else
        scheme = @"http";

    /* Try to parse port and host */
    range = [inputWorking rangeOfString:@":"];
    if (range.location != NSNotFound) {
        host = [inputWorking substringToIndex:range.location];
        inputWorking = [inputWorking substringFromIndex:range.location + [@":" length]];
        range = [inputWorking rangeOfString:@"/"];
        if (range.location != NSNotFound) {
            port = [NSNumber numberWithInt:[[inputWorking substringToIndex:range.location] intValue]];
            inputWorking = [inputWorking substringFromIndex:range.location + [@"/" length]];
        } else {
            port = [NSNumber numberWithInt:[inputWorking intValue]];
            inputWorking = @"";
        }
    } else {
        port = nil;
        range = [inputWorking rangeOfString:@"/"];
        if (range.location != NSNotFound) {
            host = [inputWorking substringToIndex:range.location];
            inputWorking = [inputWorking substringFromIndex:range.location + [@"/" length]];
        } else {
            host = inputWorking;
            inputWorking = @"";
        }
    }
    
    /* And any path given */
    if ([inputWorking length])
        path = inputWorking;
    else
        path = nil;
    
    /* Don't try non-HTTP protocols */
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"])
        scheme = @"http";
    
    /* Add potential ports and catalog names from user into list to be checked */
    if ([port intValue] == 0)
        port = nil;
    if (port) {
        NSMutableArray *newPorts = [NSMutableArray arrayWithObject:port];
        [newPorts addObjectsFromArray:catalogPorts];
        catalogPorts = newPorts;
    }
    if (path) {
        NSMutableArray *newCatalogs = [NSMutableArray arrayWithObject:path];
        [newCatalogs addObjectsFromArray:catalogNames];
        catalogNames = newCatalogs;
    }
    
    catalogNameEnumerator = [catalogNames objectEnumerator];
    while ((catalogName = [catalogNameEnumerator nextObject])) {
        catalogPortEnumerator = [catalogPorts objectEnumerator];
        while ((catalogPort = [catalogPortEnumerator nextObject])) {
            NSString *urlString;
            NSURL *url;
        
            if (([scheme isEqualToString:@"http"] && [catalogPort unsignedIntValue] != 80) ||
                ([scheme isEqualToString:@"https"] && [catalogPort unsignedIntValue] != 443))
                urlString = [NSString stringWithFormat:@"%@://%@:%u/%@", scheme, host, [catalogPort unsignedIntValue], catalogName];
            else
                urlString = [NSString stringWithFormat:@"%@://%@/%@", scheme, host, catalogName];
            
            urlString = [self stripDoubleSlashes:urlString];
            url = [NSURL URLWithString:urlString];    
            [urlList addObject:url];
        }
    }
    
    /* Strip any duplicates */
    NSArray *urlListCopy = [urlList copy];
    unsigned int index = [urlListCopy count] - 1;
    NSEnumerator *reverseObjectEnumerator = [urlListCopy reverseObjectEnumerator];
    NSString *url;
    while ((url = [reverseObjectEnumerator nextObject])) {
        if ([urlList indexOfObject:url inRange:NSMakeRange(0, index)] != NSNotFound) {
            [urlList removeObjectAtIndex:index];
        }
        index--;
    }
    [urlListCopy release];
    
    NSLog(@"Test URLs: %@", urlList);
    
    return [urlList autorelease];
}

- (NSString *)stripDoubleSlashes:(NSString *)url
{
	int length;
	NSRange range;
	NSMutableString *urlString;
	NSString *returnString;
	
	urlString = [url mutableCopy];
	length = [urlString length];
	range = NSMakeRange([urlString rangeOfString:@"://"].location + 3, length - [urlString rangeOfString:@"://"].location - 3);
	while ([urlString rangeOfString:@"//" options:0 range:range].location != NSNotFound) {
		[urlString replaceOccurrencesOfString:@"//" withString:@"/" options:NSLiteralSearch range:range];
		length = [urlString length];
		range = NSMakeRange([urlString rangeOfString:@"://"].location + 3, length - [urlString rangeOfString:@"://"].location - 3);
	}
	
	returnString = [[urlString copy] autorelease];
	[urlString release];
	return returnString;
}


#pragma mark NSConnection Delegate
- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse
{
	int statusCode;
	if ([redirectResponse isKindOfClass:[NSHTTPURLResponse class]])
		statusCode = [(NSHTTPURLResponse *)redirectResponse statusCode];
	if (statusCode >= 400 && statusCode <= 599)
		return nil;
	else
		return request;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	//[self failWithReason: [error localizedDescription]];
    NSLog(@"URL %@ failed. %@", testURL, [error localizedDescription]);
    [self tryNextURL];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    NSLog(@"URL %@ failed. %@", testURL, @"Authentication required");
    [self tryNextURL];
}

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	int statusCode;
	NSString *urlString;
	
	if ([response isKindOfClass:[NSHTTPURLResponse class]])
		statusCode = [(NSHTTPURLResponse *)response statusCode];
	if (!(statusCode >= 200 && statusCode <= 299)) {
        NSLog(@"URL %@ failed. Status code: %d", testURL, statusCode);
		[self tryNextURL];
		return;
	}
	
    NSLog(@"URL %@ looks good", testURL);
    
	urlString = [testURL absoluteString];
	[self setValue:urlString forKey:SUEUpdateServerKey];
	[self updatePreferencesOnDisk];
    
	[URLconnection release];
	URLconnection = nil;
	[testURL release];
	testURL = nil;
    [testURLs release];
    testURLs = nil;
}



#pragma mark KVC Methods
- (void)setUpdateServer:(NSString *)newUpdateServer
{
	[newUpdateServer retain];
	[updateServer release];
	updateServer = newUpdateServer;
}

#pragma mark Application Delegate
- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	NSNib *mainWindowNib;
	
	mainWindowNib = [[NSNib alloc] initWithNibNamed:@"MainWindow" bundle:nil];
	if (![mainWindowNib instantiateNibWithOwner:self topLevelObjects:nil]) {
		NSAlert *alert;
		alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Could not load main window", @"Error message if main window can't be loaded")
								defaultButton:NSLocalizedString(@"Quit", @"Default button for fatal error")
							  alternateButton:nil
								  otherButton:nil
					informativeTextWithFormat:NSLocalizedString(@"The application has been damaged. Replace the application with a fresh copy from the website.", @"Informative text if main window can't be loaded")];
		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert runModal];
		[[NSApplication sharedApplication] terminate:self];
	}
    
	[mainWindowNib release];
	
	[mainWindow orderFront:self];
	
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	return YES;
}

@end
