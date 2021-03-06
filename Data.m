//
//  Data.m
//  GPG Checker
//
//  Created by Sven-S. Porst on Thu Dec 27 2001.
//  Copyright (c) 2001-2010 earthlingsoft. All rights reserved.
//

#import "Data.h"


@implementation Data
//
// special method for making the object accessible globally
//
+ (Data *)Data
{
	static Data * _sharedData = nil;

	if (!_sharedData)
		_sharedData = [[Data allocWithZone:[self zone]] init];

	return _sharedData;
}


- (NSArray*) privateKeys {return privateKeys;}
- (void) setPrivateKeys:(NSArray*) keys
{
	NSArray * oldKeys = privateKeys;
	privateKeys = [keys retain];
	[oldKeys release];
}

- (NSArray*) cipherAlgorithms {return cipherAlgorithms;}
- (void) setCipherAlgorithms:(NSArray*) algorithms
{
	NSArray * oldAlgorithms = cipherAlgorithms;
	cipherAlgorithms = [algorithms retain];
	[oldAlgorithms release];
}


- (NSImage*) documentMiniIcon { return documentMiniIcon;}
- (NSImage*) folderMiniIcon {return folderMiniIcon;}



//
// Initialise
//
- (Data *) init
{
	NSTask *		keyTask = [[NSTask alloc] init];
	NSTask *		cipherTask = [[NSTask alloc] init];
	NSString *	gpgPath = [[NSUserDefaults standardUserDefaults] stringForKey:GPGPathKey];

	debugLog(@"[Data init]");

	// load images
	documentMiniIcon = [[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kClippingTextTypeIcon)] retain];
	[documentMiniIcon setSize: NSMakeSize(16., 16.)];
	folderMiniIcon = [[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericFolderIcon)] retain];
	[folderMiniIcon setSize: NSMakeSize(16., 16.)];
	
	// run tasks
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyTaskFinished:) name:NSTaskDidTerminateNotification object:keyTask];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cipherTaskFinished:) name:NSTaskDidTerminateNotification object:cipherTask];

	[keyTask setLaunchPath:@"/bin/tcsh"];
	[cipherTask setLaunchPath:@"/bin/tcsh"];

	[keyTask setStandardOutput:[NSPipe pipe]];
	[cipherTask setStandardOutput:[NSPipe pipe]];

	[keyTask setArguments:[NSArray arrayWithObjects:@"-c", [gpgPath stringByAppendingString:@" --list-secret-keys --with-colons --charset utf-8 | grep ^sec"],nil]];
	[cipherTask setArguments:[NSArray arrayWithObjects:@"-c", [gpgPath stringByAppendingString:@" --version --charset utf-8 | grep ^Cipher"],nil]];

// #ifdef debugbuild
// #else
	[keyTask launch];
	[cipherTask launch];
// #endif
	
	// pro forma intialisation of the arrays
	[self setCipherAlgorithms:[NSArray array]];
	[self setPrivateKeys:[NSArray array]];

	// autosaving
	[[NSDocumentController sharedDocumentController] setAutosavingDelay: 60.];
	
	return self;
}

- (void) keyTaskFinished:(NSNotification*) aNotification
{
	NSString * result =  [[[NSString alloc] initWithData:[[[[aNotification object] standardOutput] fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding] autorelease];
	NSArray * 		keylines = [result componentsSeparatedByString:@"\n"];
	NSEnumerator*	myEnum = [keylines objectEnumerator];
	NSString *		s;
	NSMutableArray* keys = [NSMutableArray arrayWithCapacity:[keylines count]];
	
	// output are lines of
	//sec:u:1024:17:93D72D600085ABA3:1998-04-09::::Sven-S. Porst <ssp@earthling.net>:::
	while (s = [myEnum nextObject]) {
		if ([s length] > 10) {
			// don't be fooled by short strings, ie. empty last line
			[keys addObject:[s componentsSeparatedByString:@":"]];
		}
	}

	[self setPrivateKeys:keys];

	debugLog(@"Data: received Keys");
}


- (void) cipherTaskFinished:(NSNotification*) aNotification
{
	NSString * result = [[[NSString alloc] initWithData:[[[[aNotification object] standardOutput] fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding] autorelease];
	// output looks like
	// Cipher: 3DES, CAST5, BLOWFISH, RIJNDAEL, RIJNDAEL192, RIJNDAEL256, TWOFISH
	// 012345678
	if ( [result length] > 8 ) {
		NSString *		ciphersString = [result substringFromIndex:8];
		NSArray *		ciphers = [ciphersString componentsSeparatedByString:@", "];
		
		[self setCipherAlgorithms:ciphers];
		
		debugLog(@"Data: received Ciphers");		
	}
}





//
// Deallocate
//
- (void) dealloc
{
	[privateKeys release];
	[cipherAlgorithms release];
	[documentMiniIcon release];
	[folderMiniIcon release];
	[super dealloc];
}

//
// Describe myself
//
- (NSString *) description
{
	return [NSString stringWithFormat:@"privateKeys: %@\n cipherAlgorithms: %@",[privateKeys description], [cipherAlgorithms description]];
}


@end
