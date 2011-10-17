/*
 * Project:     SoftwareUpdateEnabler
 * File:        SoftwareUpdatePreferences.h
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

#import "SoftwareUpdatePreferences.h"

#import <Security/Security.h>

#import <sys/param.h>
#import <sys/types.h>
#import <sys/stat.h>
#import <unistd.h>

static CFStringRef SUECatalogPreferencesKey = CFSTR("CatalogURL");
static CFStringRef SUEPreferencesDomain = CFSTR("com.apple.SoftwareUpdate");

@implementation SoftwareUpdatePreferences
+ (BOOL)canEditPreferences
{
	struct stat statinfo;
	gid_t groups[NGROUPS_MAX];
	int i;
	int numgroups;
    
    if (geteuid() == 0)
        return YES;
    
	stat("/Library/Preferences", &statinfo);
	numgroups = getgroups(NGROUPS_MAX, groups);
	
	for (i = 0; i < numgroups; i++)
	{
		if ((groups[i] == statinfo.st_gid) && (statinfo.st_mode & S_IWGRP))
			return YES;
	}
	
	return NO;
}

+ (BOOL)updateCatalogURL:(NSString *)newCatalogURL {
    if (![[self class] canEditPreferences]) {
        OSStatus status;
        AuthorizationRef authRef;
        NSString *toolPath;
        char *toolArguments[] = {"", NULL};
        
        status = AuthorizationCreate(NULL,
                                     kAuthorizationEmptyEnvironment, 
                                     kAuthorizationFlagDefaults,
                                     &authRef);
        if (status != noErr)
            return NO;
        
        toolPath = [[NSBundle mainBundle] pathForResource:@"SUEPrivilegedTool" ofType:nil];
        toolArguments[0] = (char *)[newCatalogURL UTF8String];
        status = AuthorizationExecuteWithPrivileges(authRef,
                                                   [toolPath fileSystemRepresentation],
                                                   kAuthorizationFlagDefaults,
                                                   toolArguments,
                                                   NULL);
        if (status != noErr)
            return NO;
        return YES;
    } else {
        if ([newCatalogURL isEqualToString:@""])
            newCatalogURL = nil;
        CFPreferencesSetValue(SUECatalogPreferencesKey,
                              (CFStringRef)newCatalogURL,
                              SUEPreferencesDomain,
                              kCFPreferencesAnyUser,
                              kCFPreferencesCurrentHost);
        
        if (!CFPreferencesSynchronize (SUEPreferencesDomain, kCFPreferencesAnyUser, kCFPreferencesCurrentHost)) {	
            return NO;
        } else {
            return YES;
        }
    }
}

@end
