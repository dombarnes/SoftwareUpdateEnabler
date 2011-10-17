#Software Update Enabler


In many settings it is desirable to be able to use a local software update server, but not have the computer managed by a central server. Software Update Enabler enables use of a local Software Update Server by any Mac OS X 10.4 "Tiger" and later client computer without the requirement that it be managed by the server.  

##Requirements
Software Update Enabler requires Mac OS X 10.4 "Tiger" or later.

##Installation
Simply drag the application to the desired folder on your hard disk.

##Configuration
Simply enter the URL of your local Software Update Server. In most cases you can simply enter the name of the server, and Software Update Enabler will determine the correct address. If you do not know the name of your local Software Update Server, talk to your local network administrator.

##Updating Mac OS X Versions
When you update to a new major version of Mac OS X, the URL for the Software Update Server may change. After updating Mac OS X, ensure you run Software Update Enabler again to reset the URL. You may want to ensure you've got the most up to date version to ensure that the details required for the new version of Mac OS X are supported.

##License
Please see the License file included for the License Agreement for this software.

##Source Code
The source code is available from the Software Update Enabler website at http://www.allocinit.net/apps/suenabler/.

##Special Thanks
Adam Reed and Daniel Rodwell for providing a Software Update Server to test the initial versions with.

##Version History
2.0
• Support for Mac OS X 10.6 "Snow Leopard" server and client
• Only set the update server for the whole machine, not per-user
• Ask for authentication when non-administrator attempts to set server
• Enhanced Software Update server detection

1.0.4
• Enhanced Software Update server port detection
• Correct issue preventing launching on Mac OS X 10.5 "Leopard"

1.0.3
• Add support for Recent Servers list based on idea by Matt Gray
• Built as Universal Binary running natively on PowerPC and Intel based Macs

1.0.2
• Correct a problem in 1.0.1 that caused Restore Default to fail in some cases

1.0.1
• Fix an issue where clicking the Save button with the mouse wouldn't save the server correctly

1.0
• Initial release

##Copyright
Software Update Enabler License
Copyright © 2005-2009 Andrew Wellington.
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
