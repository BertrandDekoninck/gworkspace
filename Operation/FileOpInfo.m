/* FileOpInfo.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
 *
 * This file is part of the GNUstep GWorkspace application
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "FileOpInfo.h"
#include "Operation.h"
#include "Functions.h"
#include "GNUstep.h"

#define PROGR_STEPS (100.0)
static BOOL stopped = NO;
static BOOL paused = NO;

static NSString *nibName = @"FileOperationWin";

@implementation FileOpInfo

- (void)dealloc
{
	[nc removeObserver: self];

  RELEASE (operationDict);
  RELEASE (type);
  TEST_RELEASE (source);
  TEST_RELEASE (destination);
  TEST_RELEASE (files);
  TEST_RELEASE (dupfiles);
  TEST_RELEASE (notifNames);
  TEST_RELEASE (win);
  TEST_RELEASE (progInd);
  TEST_RELEASE (progView);
  
  DESTROY (executor);
  DESTROY (execconn);
  
  [super dealloc];
}

+ (id)operationOfType:(NSString *)tp
                  ref:(int)rf
               source:(NSString *)src
          destination:(NSString *)dst
                files:(NSArray *)fls
         confirmation:(BOOL)conf
            usewindow:(BOOL)uwnd
              winrect:(NSRect)wrect
           controller:(id)cntrl
{
  return AUTORELEASE ([[self alloc] initWithOperationType: tp ref: rf
                                source: src destination: dst files: fls 
                                      confirmation: conf usewindow: uwnd 
                                        winrect: wrect controller: cntrl]);
}

- (id)initWithOperationType:(NSString *)tp
                        ref:(int)rf
                     source:(NSString *)src
                destination:(NSString *)dst
                      files:(NSArray *)fls
               confirmation:(BOOL)conf
                  usewindow:(BOOL)uwnd
                    winrect:(NSRect)wrect
                 controller:(id)cntrl
{
	self = [super init];

  if (self) {
    win = nil;
    showwin = uwnd;
  
    if (showwin) {
      NSRect r;
      
		  if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
        NSLog(@"failed to load %@!", nibName);
        DESTROY (self);
        return self;
      }
      
      if (NSEqualRects(wrect, NSZeroRect) == NO) {
        [win setFrame: wrect display: NO];
      } else if ([win setFrameUsingName: @"fopinfo"] == NO) {
        [win setFrame: NSMakeRect(300, 300, 282, 102) display: NO];
      }

      RETAIN (progInd);
      r = [[progBox contentView] frame];
      progView = [[OpProgressView alloc] initWithFrame: r refreshInterval: 0.05];

      [fromLabel setStringValue: NSLocalizedString(@"From:", @"")];
      [toLabel setStringValue: NSLocalizedString(@"To:", @"")];
      [pauseButt setTitle: NSLocalizedString(@"Pause", @"")];
      [stopButt setTitle: NSLocalizedString(@"Stop", @"")];      
    }
    
    ref = rf;
    controller = cntrl;
    fm = [NSFileManager defaultManager];
    nc = [NSNotificationCenter defaultCenter];
    dnc = [NSDistributedNotificationCenter defaultCenter];
    
    ASSIGN (type, tp);
    ASSIGN (source, src);
    ASSIGN (destination, dst);
    ASSIGN (files, fls);
    
    dupfiles = [NSMutableArray new];
    
    if ([type isEqual: @"NSWorkspaceDuplicateOperation"]) {    
      NSString *copystr = NSLocalizedString(@"_copy", @"");
      unsigned i;
      
      for (i = 0; i < [files count]; i++) {
        NSDictionary *fdict = [files objectAtIndex: i];
        NSString *fname = [fdict objectForKey: @"name"]; 
        NSString *newname = [NSString stringWithString: fname];
        NSString *ext = [newname pathExtension]; 
        NSString *base = [newname stringByDeletingPathExtension];        
        NSString *ntmp;
	      NSString *destpath;        
        int count = 1;
	      
	      while (1) {
          if (count == 1) {
            ntmp = [NSString stringWithFormat: @"%@%@", base, copystr];
            if ([ext length]) {
              ntmp = [ntmp stringByAppendingPathExtension: ext];
            }
          } else {
            ntmp = [NSString stringWithFormat: @"%@%@%i", base, copystr, count];
            if ([ext length]) {
              ntmp = [ntmp stringByAppendingPathExtension: ext];
            }
          }

		      destpath = [destination stringByAppendingPathComponent: ntmp];

		      if ([fm fileExistsAtPath: destpath] == NO) {
            newname = ntmp;
			      break;
          } else {
            count++;
          }
	      }
        
        [dupfiles addObject: newname];
      }
    }
    
    operationDict = [NSMutableDictionary new];
    [operationDict setObject: type forKey: @"operation"]; 
    [operationDict setObject: [NSNumber numberWithInt: ref] forKey: @"ref"];
    [operationDict setObject: source forKey: @"source"]; 
    [operationDict setObject: destination forKey: @"destination"]; 
    [operationDict setObject: files forKey: @"files"]; 

    confirm = conf;
    executor = nil;
    opdone = NO;
  }
  
	return self;
}

- (void)startOperation
{
  NSPort *port[2];
  NSArray *ports;

  if (confirm) {    
	  NSString *title;
	  NSString *msg, *msg1, *msg2;
    NSString *items;

    if ([files count] > 1) {
      items = [NSString stringWithFormat: @"%i %@", [files count], NSLocalizedString(@"items", @"")];
    } else {
      items = NSLocalizedString(@"one item", @"");
    }
    
	  if ([type isEqual: @"NSWorkspaceMoveOperation"]) {
		  title = NSLocalizedString(@"Move", @"");
      msg1 = [NSString stringWithFormat: @"%@ %@ %@: ", 
                                            NSLocalizedString(@"Move", @""), 
                                            items, 
                                            NSLocalizedString(@"from", @"")];
		  msg2 = NSLocalizedString(@"\nto: ", @"");
		  msg = [NSString stringWithFormat: @"%@%@%@%@?", msg1, source, msg2, destination];
    } else if ([type isEqual: @"NSWorkspaceCopyOperation"]) {
		  title = NSLocalizedString(@"Copy", @"");
      msg1 = [NSString stringWithFormat: @"%@ %@ %@: ", 
                                            NSLocalizedString(@"Copy", @""), 
                                            items, 
                                            NSLocalizedString(@"from", @"")];
		  msg2 = NSLocalizedString(@"\nto: ", @"");
		  msg = [NSString stringWithFormat: @"%@%@%@%@?", msg1, source, msg2, destination];
	  } else if ([type isEqual: @"NSWorkspaceLinkOperation"]) {
		  title = NSLocalizedString(@"Link", @"");
      msg1 = [NSString stringWithFormat: @"%@ %@ %@: ", 
                                            NSLocalizedString(@"Link", @""), 
                                            items, 
                                            NSLocalizedString(@"from", @"")];
		  msg2 = NSLocalizedString(@"\nto: ", @"");
		  msg = [NSString stringWithFormat: @"%@%@%@%@?", msg1, source, msg2, destination];
	  } else if ([type isEqual: @"NSWorkspaceRecycleOperation"]) {
		  title = NSLocalizedString(@"Recycler", @"");
      msg1 = [NSString stringWithFormat: @"%@ %@ %@: ", 
                                            NSLocalizedString(@"Move", @""), 
                                            items, 
                                            NSLocalizedString(@"from", @"")];
		  msg2 = NSLocalizedString(@"\nto the Recycler", @"");
		  msg = [NSString stringWithFormat: @"%@%@%@?", msg1, source, msg2];
	  } else if ([type isEqual: @"GWorkspaceRecycleOutOperation"]) {
		  title = NSLocalizedString(@"Recycler", @"");
      msg1 = [NSString stringWithFormat: @"%@ %@ %@ ", 
                                            NSLocalizedString(@"Move", @""), 
                                            items, 
                                            NSLocalizedString(@"from the Recycler", @"")];
		  msg2 = NSLocalizedString(@"\nto: ", @"");
		  msg = [NSString stringWithFormat: @"%@%@%@?", msg1, msg2, destination];
	  } else if ([type isEqual: @"GWorkspaceEmptyRecyclerOperation"]) {
		  title = NSLocalizedString(@"Recycler", @"");
		  msg = NSLocalizedString(@"Empty the Recycler?", @"");
	  } else if ([type isEqual: @"NSWorkspaceDestroyOperation"]) {
		  title = NSLocalizedString(@"Delete", @"");
		  msg = NSLocalizedString(@"Delete the selected objects?", @"");
	  } else if ([type isEqual: @"NSWorkspaceDuplicateOperation"]) {
		  title = NSLocalizedString(@"Duplicate", @"");
		  msg = NSLocalizedString(@"Duplicate the selected objects?", @"");
	  }
        
    if (NSRunAlertPanel(title, msg, 
                        NSLocalizedString(@"OK", @""), 
				                NSLocalizedString(@"Cancel", @""), 
                        nil) != NSAlertDefaultReturn) {
      [self endOperation];
      return;
    }
  } 

  port[0] = (NSPort *)[NSPort port];
  port[1] = (NSPort *)[NSPort port];

  ports = [NSArray arrayWithObjects: port[1], port[0], nil];

  execconn = [[NSConnection alloc] initWithReceivePort: port[0]
				                                      sendPort: port[1]];
  [execconn setRootObject: self];
  [execconn setDelegate: self];

  [nc addObserver: self
         selector: @selector(connectionDidDie:)
             name: NSConnectionDidDieNotification
           object: execconn];    

  NS_DURING
    {
      [NSThread detachNewThreadSelector: @selector(setPorts:)
		                           toTarget: [FileOpExecutor class]
		                         withObject: ports];
    }
  NS_HANDLER
    {
      NSRunAlertPanel(nil, 
                      NSLocalizedString(@"A fatal error occured while detaching the thread!", @""), 
                      NSLocalizedString(@"Continue", @""), 
                      nil, 
                      nil);
      [self endOperation];
    }
  NS_ENDHANDLER
}

- (int)requestUserConfirmationWithMessage:(NSString *)message 
                                    title:(NSString *)title
{  
  return NSRunAlertPanel(NSLocalizedString(title, @""),
												 NSLocalizedString(message, @""),
											   NSLocalizedString(@"Ok", @""), 
												 NSLocalizedString(@"Cancel", @""), 
                         nil);       
}

- (int)showErrorAlertWithMessage:(NSString *)message
{  
  return NSRunAlertPanel(nil, 
                         NSLocalizedString(message, @""), 
												 NSLocalizedString(@"Ok", @""), 
                         nil, 
                         nil);
}

- (IBAction)pause:(id)sender
{
	if (paused == NO) {
		[pauseButt setTitle: NSLocalizedString(@"Continue", @"")];
		[stopButt setEnabled: NO];	
    paused = YES;
	} else {
		[pauseButt setTitle: NSLocalizedString(@"Pause", @"")];
		[stopButt setEnabled: YES];	
    paused = NO;
		[executor performOperation];
	}
}

- (IBAction)stop:(id)sender
{
  stopped = YES;   
}

- (void)showProgressWin
{  
  if ([win isVisible] == NO) {
    if ([type isEqual: @"NSWorkspaceMoveOperation"]) {
      [win setTitle: NSLocalizedString(@"Move", @"")];
      [fromLabel setStringValue: NSLocalizedString(@"From:", @"")];
      [fromField setStringValue: relativePathFittingInField(fromField, source)];
      [toLabel setStringValue: NSLocalizedString(@"To:", @"")];
      [toField setStringValue: relativePathFittingInField(fromField, destination)];
    
    } else if ([type isEqual: @"NSWorkspaceCopyOperation"]) {
      [win setTitle: NSLocalizedString(@"Copy", @"")];
      [fromLabel setStringValue: NSLocalizedString(@"From:", @"")];
      [fromField setStringValue: relativePathFittingInField(fromField, source)];
      [toLabel setStringValue: NSLocalizedString(@"To:", @"")];
      [toField setStringValue: relativePathFittingInField(fromField, destination)];
    
    } else if ([type isEqual: @"NSWorkspaceLinkOperation"]) {
      [win setTitle: NSLocalizedString(@"Link", @"")];
      [fromLabel setStringValue: NSLocalizedString(@"From:", @"")];
      [fromField setStringValue: relativePathFittingInField(fromField, source)];
      [toLabel setStringValue: NSLocalizedString(@"To:", @"")];
      [toField setStringValue: relativePathFittingInField(fromField, destination)];
    
    } else if ([type isEqual: @"NSWorkspaceDuplicateOperation"]) {
      [win setTitle: NSLocalizedString(@"Duplicate", @"")];
      [fromLabel setStringValue: NSLocalizedString(@"In:", @"")];
      [fromField setStringValue: relativePathFittingInField(fromField, destination)];
      [toLabel setStringValue: @""];
      [toField setStringValue: @""];
    
    } else if ([type isEqual: @"NSWorkspaceDestroyOperation"]) {
      [win setTitle: NSLocalizedString(@"Destroy", @"")];
      [fromLabel setStringValue: NSLocalizedString(@"In:", @"")];
      [fromField setStringValue: relativePathFittingInField(fromField, destination)];
      [toLabel setStringValue: @""];
      [toField setStringValue: @""];
    
    } else if ([type isEqual: @"NSWorkspaceRecycleOperation"]) {
      [win setTitle: NSLocalizedString(@"Move", @"")];
      [fromLabel setStringValue: NSLocalizedString(@"From:", @"")];
      [fromField setStringValue: relativePathFittingInField(fromField, source)];
      [toLabel setStringValue: NSLocalizedString(@"To:", @"")];
      [toField setStringValue: NSLocalizedString(@"the Recycler", @"")];
        
    } else if ([type isEqual: @"GWorkspaceRecycleOutOperation"]) {
      [win setTitle: NSLocalizedString(@"Move", @"")];
      [fromLabel setStringValue: NSLocalizedString(@"From:", @"")];
      [fromField setStringValue: NSLocalizedString(@"the Recycler", @"")];
      [toLabel setStringValue: NSLocalizedString(@"To:", @"")];
      [toField setStringValue: relativePathFittingInField(fromField, destination)];
                            
    } else if ([type isEqual: @"GWorkspaceEmptyRecyclerOperation"]) {
      [win setTitle: NSLocalizedString(@"Destroy", @"")];
      [fromLabel setStringValue: NSLocalizedString(@"In:", @"")];
      [fromField setStringValue: NSLocalizedString(@"the Recycler", @"")];
      [toLabel setStringValue: @""];
      [toField setStringValue: @""];    
    }
    
    [progBox setContentView: progView];
    [progView start];
  }
  
  [win orderFront: nil];
  showwin = YES;
}

- (void)setNumFiles:(int)n
{
  [progView stop];  
  [progBox setContentView: progInd];
  [progInd setMinValue: 0.0];
  [progInd setMaxValue: n];
  [progInd setDoubleValue: 0.0];
  [executor performOperation]; 
}

- (void)setProgIndicatorValue:(int)n
{
  [progInd setDoubleValue: n];
}

- (void)endOperation
{
  if (showwin) {
    if ([progBox contentView] == progView) {
      [progView stop];  
    }
    [win saveFrameUsingName: @"fopinfo"];
    [win close];
  }
  
  if (executor) {
    [nc removeObserver: self
	                name: NSConnectionDidDieNotification 
                object: execconn];
    [executor exitThread];
    DESTROY (executor);
    DESTROY (execconn);
  }
  
  [controller endOfFileOperation: self];
}

- (void)sendWillChangeNotification
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];	
  int i;
    
  notifNames = [NSMutableArray new];
  
  for (i = 0; i < [files count]; i++) {
    NSDictionary *fdict = [files objectAtIndex: i];
    NSString *name = [fdict objectForKey: @"name"]; 
    [notifNames addObject: name];
  }
  
	[dict setObject: type forKey: @"operation"];	
  [dict setObject: source forKey: @"source"];	
  [dict setObject: destination forKey: @"destination"];	
  [dict setObject: notifNames forKey: @"files"];	

  [nc postNotificationName: @"GWFileSystemWillChangeNotification"
	 								  object: dict];

	[dnc postNotificationName: @"GWFileSystemWillChangeNotification"
	 								   object: nil 
                   userInfo: dict];
}

- (void)sendDidChangeNotification
{
  NSMutableDictionary *notifObj = [NSMutableDictionary dictionary];		

	[notifObj setObject: type forKey: @"operation"];	
  [notifObj setObject: source forKey: @"source"];	
  [notifObj setObject: destination forKey: @"destination"];	
  
  if (executor) {
    NSData *data = [executor processedFiles];
    NSArray *procFiles = [NSUnarchiver unarchiveObjectWithData: data];
    
    [notifObj setObject: procFiles forKey: @"files"];	
    [notifObj setObject: notifNames forKey: @"origfiles"];	
  } else {
    [notifObj setObject: notifNames forKey: @"files"];
    [notifObj setObject: notifNames forKey: @"origfiles"];	
  }
  
  opdone = YES;			

  [nc postNotificationName: @"GWFileSystemDidChangeNotification"
	 								  object: notifObj];

	[dnc postNotificationName: @"GWFileSystemDidChangeNotification"
	 						       object: nil 
                   userInfo: notifObj];  
}

- (void)registerExecutor:(id)anObject
{
  NSData *opinfo = [NSArchiver archivedDataWithRootObject: operationDict];
  BOOL samename;

  [anObject setProtocolForProxy: @protocol(FileOpExecutorProtocol)];
  executor = (id <FileOpExecutorProtocol>)[anObject retain];
  
  [executor setOperation: opinfo];  
  samename = [executor checkSameName];
  
  if (samename) {
	  NSString *msg, *title;
    int result;
    
		if ([type isEqual: @"NSWorkspaceMoveOperation"]) {	
			msg = @"Some items have the same name;\ndo you want to replace them?";
			title = @"Move";
		
		} else if ([type isEqual: @"NSWorkspaceCopyOperation"]) {
			msg = @"Some items have the same name;\ndo you want to replace them?";
			title = @"Copy";

		} else if ([type isEqual: @"NSWorkspaceLinkOperation"]) {
			msg = @"Some items have the same name;\ndo you want to replace them?";
			title = @"Link";

		} else if ([type isEqual: @"NSWorkspaceRecycleOperation"]) {
			msg = @"Some items have the same name;\ndo you want to replace them?";
			title = @"Recycle";

		} else if ([type isEqual: @"GWorkspaceRecycleOutOperation"]) {
			msg = @"Some items have the same name;\ndo you want to replace them?";
			title = @"Recycle";
		}
        
    result = NSRunAlertPanel(NSLocalizedString(title, @""),
														 NSLocalizedString(msg, @""),
														 NSLocalizedString(@"OK", @""), 
														 NSLocalizedString(@"Cancel", @""), 
                             NSLocalizedString(@"Only older", @"")); 

		if (result == NSAlertAlternateReturn) {  
      [controller endOfFileOperation: self];
      return;   
		} else if (result == NSAlertOtherReturn) {  
      [executor setOnlyOlder];
    }
  } 
      
  if (showwin) {
    [self showProgressWin];
  }

  [self sendWillChangeNotification]; 
  
  stopped = NO;
  paused = NO;   
  [executor calculateNumFiles];
}

- (BOOL)connection:(NSConnection*)ancestor 
								shouldMakeNewConnection:(NSConnection*)newConn
{
	if (ancestor == execconn) {
  	[newConn setDelegate: self];
  	[nc addObserver: self 
					 selector: @selector(connectionDidDie:)
	    				 name: NSConnectionDidDieNotification 
             object: newConn];
  	return YES;
	}
		
  return NO;
}

- (void)connectionDidDie:(NSNotification *)notification
{
  [nc removeObserver: self
	              name: NSConnectionDidDieNotification 
              object: [notification object]];

  if (opdone == NO) {
    NSRunAlertPanel(nil, 
                    NSLocalizedString(@"executor connection died!", @""), 
                    NSLocalizedString(@"Continue", @""), 
                    nil, 
                    nil);
    [self sendDidChangeNotification];
    [self endOperation];
  }
}

- (NSString *)type
{
  return type;
}

- (NSString *)source
{
  return source;
}

- (NSString *)destination
{
  return destination;
}

- (NSArray *)files
{
  return files;
}

- (NSArray *)dupfiles
{
  return dupfiles;
}

- (int)ref
{
  return ref;
}

- (BOOL)showsWindow
{
  return showwin;
}

- (NSWindow *)win
{
  return win;
}

- (NSRect)winRect
{
  if (win && [win isVisible]) {
    return [win frame];
  }
  return NSZeroRect;
}

@end


@implementation FileOpExecutor

+ (void)setPorts:(NSArray *)thePorts
{
  NSAutoreleasePool *pool;
  NSPort *port[2];
  NSConnection *conn;
  FileOpExecutor *executor;
               
  pool = [[NSAutoreleasePool alloc] init];
               
  port[0] = [thePorts objectAtIndex: 0];             
  port[1] = [thePorts objectAtIndex: 1];             

  conn = [NSConnection connectionWithReceivePort: (NSPort *)port[0]
                                        sendPort: (NSPort *)port[1]];
  
  executor = [[self alloc] init];
  [executor setFileop: thePorts];
  [(id)[conn rootProxy] registerExecutor: executor];
  RELEASE (executor);
                              
  [[NSRunLoop currentRunLoop] run];
  RELEASE (pool);
}

- (void)dealloc
{
  TEST_RELEASE (operation);
  TEST_RELEASE (source);
  TEST_RELEASE (destination);
  TEST_RELEASE (files);
  TEST_RELEASE (procfiles);
	[super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
    fm = [NSFileManager defaultManager];
		samename = NO;
    onlyolder = NO;
  }
  
  return self;
}

- (void)setFileop:(NSArray *)thePorts
{
  NSPort *port[2];
  NSConnection *conn;
  id anObject;
  
  port[0] = [thePorts objectAtIndex: 0];             
  port[1] = [thePorts objectAtIndex: 1];             

  conn = [NSConnection connectionWithReceivePort: (NSPort *)port[0]
                                        sendPort: (NSPort *)port[1]];

  anObject = (id)[conn rootProxy];
  [anObject setProtocolForProxy: @protocol(FileOpInfoProtocol)];
  fileOp = (id <FileOpInfoProtocol>)anObject;
}

- (BOOL)setOperation:(NSData *)opinfo
{
  NSDictionary *opDict = [NSUnarchiver unarchiveObjectWithData: opinfo];
  id dictEntry;

  dictEntry = [opDict objectForKey: @"operation"];
  if (dictEntry) {
    ASSIGN (operation, dictEntry);   
  } 

  dictEntry = [opDict objectForKey: @"source"];
  if (dictEntry) {
    ASSIGN (source, dictEntry);
  }  

  dictEntry = [opDict objectForKey: @"destination"];
  if (dictEntry) {
    ASSIGN (destination, dictEntry);
  }  

  files = [NSMutableArray new];
  dictEntry = [opDict objectForKey: @"files"];
  if (dictEntry) {
    [files addObjectsFromArray: dictEntry];
  }		
  
  procfiles = [NSMutableArray new];
  
  return YES;
}

- (BOOL)checkSameName
{
	NSArray *dirContents;
	int i;
    
	samename = NO;

  if (([operation isEqual: @"GWorkspaceRenameOperation"])
        || ([operation isEqual: @"GWorkspaceCreateDirOperation"])
        || ([operation isEqual: @"GWorkspaceCreateFileOperation"])) {
    /* already checked by GWorkspace */
	  return NO;
  }
  
	if (destination && [files count]) {
		dirContents = [fm directoryContentsAtPath: destination];
		for (i = 0; i < [files count]; i++) {
      NSDictionary *dict = [files objectAtIndex: i];
      NSString *name = [dict objectForKey: @"name"]; 
    
      if ([dirContents containsObject: name]) {
        samename = YES;
        break;
      }
		}
	}
	
	if (samename) {
		if (([operation isEqual: @"NSWorkspaceMoveOperation"]) 
          || ([operation isEqual: @"NSWorkspaceCopyOperation"])
          || ([operation isEqual: @"NSWorkspaceLinkOperation"])
          || ([operation isEqual: @"GWorkspaceRecycleOutOperation"])) {
      return YES;
      
		} else if (([operation isEqual: @"NSWorkspaceDestroyOperation"]) 
          || ([operation isEqual: @"NSWorkspaceDuplicateOperation"])
          || ([operation isEqual: @"NSWorkspaceRecycleOperation"])
          || ([operation isEqual: @"GWorkspaceEmptyRecyclerOperation"])) {
      return NO;
		} 
	}
  
  return NO;
}

- (void)setOnlyOlder
{
  onlyolder = YES;
}

- (oneway void)calculateNumFiles
{
  int i, fnum = 0;

  for (i = 0; i < [files count]; i++) {
    CREATE_AUTORELEASE_POOL (arp);
    NSDictionary *dict = [files objectAtIndex: i];
    NSString *name = [dict objectForKey: @"name"]; 
    NSString *path = [source stringByAppendingPathComponent: name];       
	  BOOL isDir = NO;
    
	  [fm fileExistsAtPath: path isDirectory: &isDir];
    
	  if (isDir) {
      NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath: path];
      
      while (1) {
        CREATE_AUTORELEASE_POOL (arp2);
        NSString *dirEntry = [enumerator nextObject];
      
        if (dirEntry) {
          if (stopped) {
            break;
          }
			    fnum++;
        
        } else {
          RELEASE (arp2);
          break;
        }
      
        RELEASE (arp2);
      }
            
	  } else {
		  fnum++;
	  }
    
    if (stopped) {
      RELEASE (arp);
      break;
    }
    
    RELEASE (arp);
  }

  if (stopped) {
    [self done];
  }

  fcount = 0;
  stepcount = 0;
  
  if (fnum < PROGR_STEPS) {
    progstep = 1.0;
  } else {
    progstep = fnum / PROGR_STEPS;
  }
  
  [fileOp setNumFiles: fnum];
}

- (oneway void)performOperation
{
	canupdate = YES; 
          
	if ([operation isEqual: @"NSWorkspaceMoveOperation"]
						|| [operation isEqual: @"GWorkspaceRecycleOutOperation"]) {
		[self doMove];
	} else if ([operation isEqual: @"NSWorkspaceCopyOperation"]) {  
		[self doCopy];
	} else if ([operation isEqual: @"NSWorkspaceLinkOperation"]) {
		[self doLink];
	} else if ([operation isEqual: @"NSWorkspaceDestroyOperation"]
					|| [operation isEqual: @"GWorkspaceEmptyRecyclerOperation"]) {
		[self doRemove];
	} else if ([operation isEqual: @"NSWorkspaceDuplicateOperation"]) {
		[self doDuplicate];
	} else if ([operation isEqual: @"NSWorkspaceRecycleOperation"]) {
		[self doTrash];
	} else if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
		[self doRename];
	} else if ([operation isEqual: @"GWorkspaceCreateDirOperation"]) {
		[self doNewFolder];
	} else if ([operation isEqual: @"GWorkspaceCreateFileOperation"]) {
		[self doNewFile];
  }
}

- (NSData *)processedFiles
{
  return [NSArchiver archivedDataWithRootObject: procfiles];
}

#define CHECK_DONE \
if (([files count] == 0) || stopped || paused) break

#define GET_FILENAME \
fileinfo = [files objectAtIndex: 0]; \
RETAIN (fileinfo); \
filename = [fileinfo objectForKey: @"name"]; 

- (void)doMove
{
  while (1) {
	  CHECK_DONE;	
	  GET_FILENAME;    

    if ((samename == NO) || (samename && [self removeExisting: fileinfo])) {
	    if ([fm movePath: [source stringByAppendingPathComponent: filename]
				        toPath: [destination stringByAppendingPathComponent: filename]
	 		         handler: self]) {          
        [procfiles addObject: filename];	
      }
    }
 	  [files removeObject: fileinfo];	
    RELEASE (fileinfo);
  }
  
  if (([files count] == 0) || stopped) {
    [self done];
  }
}

- (void)doCopy
{
  while (1) {
	  CHECK_DONE;	
	  GET_FILENAME;   

    if ((samename == NO) || (samename && [self removeExisting: fileinfo])) {
	    if ([fm copyPath: [source stringByAppendingPathComponent: filename]
				        toPath: [destination stringByAppendingPathComponent: filename]
	 		         handler: self]) {
        [procfiles addObject: filename];	
      }
    }
	  [files removeObject: fileinfo];	
    RELEASE (fileinfo); 
  }

  if (([files count] == 0) || stopped) {
    [self done];
  }                                          
}

- (void)doLink
{
  while (1) {
	  CHECK_DONE;	
	  GET_FILENAME;    
    
    if ((samename == NO) || (samename && [self removeExisting: fileinfo])) {
      NSString *dst = [destination stringByAppendingPathComponent: filename];
      NSString *src = [source stringByAppendingPathComponent: filename];
  
      if ([fm createSymbolicLinkAtPath: dst pathContent: src]) {
        [procfiles addObject: filename];	      
      }
    }
	  [files removeObject: fileinfo];	   
    RELEASE (fileinfo);     
  }

  if (([files count] == 0) || stopped) {
    [self done];
  }                                            
}

- (void)doRemove
{
  while (1) {
	  CHECK_DONE;	
	  GET_FILENAME;  
	  
	  if ([fm removeFileAtPath: [destination stringByAppendingPathComponent: filename]
				             handler: self]) {
      [procfiles addObject: filename];
    }
	  [files removeObject: fileinfo];	 
    RELEASE (fileinfo);   
  }

  if (([files count] == 0) || stopped) {
    [self done];
  }                                       
}

- (void)doDuplicate
{
  NSString *copystr = NSLocalizedString(@"_copy", @"");
  NSString *base;
  NSString *ext;
	NSString *destpath;
	NSString *newname;
  NSString *ntmp;

  while (1) {
    int count = 1;

	  CHECK_DONE;    
	  GET_FILENAME;  

	  newname = [NSString stringWithString: filename];
    ext = [newname pathExtension]; 
    base = [newname stringByDeletingPathExtension];
    
	  while (1) {
      if (count == 1) {
        ntmp = [NSString stringWithFormat: @"%@%@", base, copystr];
        if ([ext length]) {
          ntmp = [ntmp stringByAppendingPathExtension: ext];
        }
      } else {
        ntmp = [NSString stringWithFormat: @"%@%@%i", base, copystr, count];
        if ([ext length]) {
          ntmp = [ntmp stringByAppendingPathExtension: ext];
        }
      }
      
		  destpath = [destination stringByAppendingPathComponent: ntmp];

		  if ([fm fileExistsAtPath: destpath] == NO) {
        newname = ntmp;
			  break;
      } else {
        count++;
      }
	  }

	  if ([fm copyPath: [destination stringByAppendingPathComponent: filename]
				      toPath: destpath 
			       handler: self]) {
      [procfiles addObject: newname];	
    }
	  [files removeObject: fileinfo];
    RELEASE (fileinfo);	       
  }
  
  if (([files count] == 0) || stopped) {
    [self done];
  }                                             
}

- (void)doRename
{
	GET_FILENAME;    

	if ([fm movePath: source toPath: destination handler: self]) {         
    [procfiles addObject: filename];
  }
	[files removeObject: fileinfo];
  RELEASE (fileinfo);	

  [self done];
}

- (void)doNewFolder
{
	GET_FILENAME;  

	if ([fm createDirectoryAtPath: [destination stringByAppendingPathComponent: filename]
				             attributes: nil]) {
    [procfiles addObject: filename];
  }
	[files removeObject: fileinfo];	
  RELEASE (fileinfo);

  [self done];
}

- (void)doNewFile
{
	GET_FILENAME;  

	if ([fm createFileAtPath: [destination stringByAppendingPathComponent: filename]
				          contents: nil
                attributes: nil]) {
    [procfiles addObject: filename];
  }
	[files removeObject: fileinfo];	
  RELEASE (fileinfo);
  
  [self done];
}

- (void)doTrash
{
  NSString *copystr = NSLocalizedString(@"_copy", @"");
	NSString *destpath;
	NSString *newname;
  NSString *ntmp;

  while (1) {
	  CHECK_DONE;      
	  GET_FILENAME;  

    newname = [NSString stringWithString: filename];
    destpath = [destination stringByAppendingPathComponent: newname];
    
    if ([fm fileExistsAtPath: destpath]) {
      NSString *ext = [filename pathExtension]; 
      NSString *base = [filename stringByDeletingPathExtension]; 
      int count = 1;
      
      newname = [NSString stringWithString: filename];
      
	    while (1) {
        if (count == 1) {
          ntmp = [NSString stringWithFormat: @"%@%@", base, copystr];
          if ([ext length]) {
            ntmp = [ntmp stringByAppendingPathExtension: ext];
          }
        } else {
          ntmp = [NSString stringWithFormat: @"%@%@%i", base, copystr, count];
          if ([ext length]) {
            ntmp = [ntmp stringByAppendingPathExtension: ext];
          }
        }

		    destpath = [destination stringByAppendingPathComponent: ntmp];

		    if ([fm fileExistsAtPath: destpath] == NO) {
          newname = ntmp;
			    break;
        } else {
          count++;
        }
	    }
    }

	  if ([fm movePath: [source stringByAppendingPathComponent: filename]
				      toPath: destpath 
			       handler: self]) {
      [procfiles addObject: newname];	
    }
	  [files removeObject: fileinfo];	 
    RELEASE (fileinfo);  
  }
  
  if (([files count] == 0) || stopped) {
    [self done];
  }                                             
}

- (BOOL)removeExisting:(NSDictionary *)info
{
  NSString *fname =  [info objectForKey: @"name"];
	NSString *destpath = [destination stringByAppendingPathComponent: fname]; 
    
	canupdate = NO; 
  
	if ([fm fileExistsAtPath: destpath]) {
    if (onlyolder) {
      NSDictionary *attributes = [fm fileAttributesAtPath: destpath traverseLink: NO];
      NSDate *dstdate = [attributes objectForKey: NSFileModificationDate];
      NSDate *srcdate = [info objectForKey: @"date"];
    
      if ([srcdate isEqual: dstdate] == NO) {
        if ([[srcdate earlierDate: dstdate] isEqual: srcdate]) {
          canupdate = YES;
          return NO;
        }
      } else {
        canupdate = YES;
        return NO;
      }
    }
  
		[fm removeFileAtPath: destpath handler: self]; 
	}
  
	canupdate = YES;
  
  return YES;
}

- (NSDictionary *)infoForFilename:(NSString *)name
{
  int i;

  for (i = 0; i < [files count]; i++) {
    NSDictionary *info = [files objectAtIndex: i];

    if ([[info objectForKey: @"name"] isEqual: name]) {
      return info;
    }
  }
  
  return nil;
}

- (void)done
{
  [fileOp sendDidChangeNotification];
  [fileOp endOperation];  
}

- (oneway void)exitThread
{
  [NSThread exit];
}

- (BOOL)fileManager:(NSFileManager *)manager 
              shouldProceedAfterError:(NSDictionary *)errorDict
{  
  NSString *path;
  NSString *error;
  NSString *msg;
  int result;

  error = [errorDict objectForKey: @"Error"];

  if ([error hasPrefix: @"Unable to change NSFileOwnerAccountID to to"]
        || [error hasPrefix: @"Unable to change NSFileOwnerAccountName to"]
        || [error hasPrefix: @"Unable to change NSFileGroupOwnerAccountID to"]
        || [error hasPrefix: @"Unable to change NSFileGroupOwnerAccountName to"]
        || [error hasPrefix: @"Unable to change NSFilePosixPermissions to"]
        || [error hasPrefix: @"Unable to change NSFileModificationDate to"]) {
    return YES;
  }

  path = [NSString stringWithString: [errorDict objectForKey: @"Path"]];
  
  msg = [NSString stringWithFormat: @"%@ %@\n%@ %@\n",
							NSLocalizedString(@"File operation error:", @""),
							error,
							NSLocalizedString(@"with file:", @""),
							path];

  result = [fileOp requestUserConfirmationWithMessage: msg title: @"Error"];
    
  if (result != NSAlertDefaultReturn) {
    [self done];
    
	} else {  
    BOOL found = NO;
    
    while (1) { 
      NSDictionary *info = [self infoForFilename: [path lastPathComponent]];
          
      if ([path isEqual: source]) {
        break;      
      }    
     
      if (info) {
        [files removeObject: info];
        found = YES;
        break;
      }
         
      path = [path stringByDeletingLastPathComponent];
    }   
    
    if ([files count]) {
      if (found) {
        [self performOperation]; 
      } else {
        result = [fileOp showErrorAlertWithMessage: @"File Operation Error!"];
        [self done];
      }
    } else {
      [self done];
    }
  }
  
	return YES;
}

- (void)fileManager:(NSFileManager *)manager willProcessPath:(NSString *)path
{
  if (canupdate) {
    fcount++;
    stepcount++;
    
    if (stepcount >= progstep) {
      stepcount = 0;
      [fileOp setProgIndicatorValue: fcount];
    }
  }
  
  if (stopped) {
    [self done];
  }                                             
}

@end

/*
@implementation NSFileManager (FileOp)

- (BOOL)copyPath:(NSString *)source
	        toPath:(NSString *)destination
	       handler:(id)handler
{
  NSDictionary *attrs;
  NSString *fileType;

  if ([self fileExistsAtPath: destination] == YES) {
    return NO;
  }
  attrs = [self fileAttributesAtPath: source traverseLink: NO];
  if (attrs == nil) {
    return NO;
  }
  fileType = [attrs fileType];
  if ([fileType isEqualToString: NSFileTypeDirectory] == YES) {
    // If destination directory is a descendant of source directory copying
	  // isn't possible. 
    if ([[destination stringByAppendingString: @"/"]
	                  hasPrefix: [source stringByAppendingString: @"/"]]) {
	    return NO;
	  }

    [(id <FMProtocol>)self _sendToHandler: handler willProcessPath: destination];

    if ([self fileExistsAtPath: destination]) {
      return NO;
    }

    if ([self createDirectoryAtPath: destination attributes: attrs] == NO) {
      BOOL isdir;
      
      if (([self fileExistsAtPath: destination isDirectory: &isdir] && isdir) == NO) {
        return [(id <FMProtocol>)self _proceedAccordingToHandler: handler
					                          forError: _lastError
					                            inPath: destination
					                          fromPath: source
					                            toPath: destination];
	    }
    }

    if ([(id <FMProtocol>)self _copyPath: source 
                                  toPath: destination 
                                 handler: handler] == NO) {
	    return NO;
	  }
  
  } else if ([fileType isEqualToString: NSFileTypeSymbolicLink] == YES) {
    NSString	*path;
    BOOL	result;

    [(id <FMProtocol>)self _sendToHandler: handler willProcessPath: source];

    path = [self pathContentOfSymbolicLinkAtPath: source];
    result = [self createSymbolicLinkAtPath: destination pathContent: path];
    if (result == NO) {
      result = [(id <FMProtocol>)self _proceedAccordingToHandler: handler
					                            forError: @"cannot link to file"
					                              inPath: source
					                            fromPath: source
					                              toPath: destination];
	    if (result == NO) {
	      return NO;
	    }
	  }
    
  } else {
    [(id <FMProtocol>)self _sendToHandler: handler willProcessPath: source];

    if ([(id <FMProtocol>)self _copyFile: source 
                                  toFile: destination 
                                 handler: handler] == NO) {
	    return NO;
	  }
  }
  
  [self changeFileAttributes: attrs atPath: destination];
  
  return YES;
}

- (BOOL)_copyPath:(NSString *)source
	         toPath:(NSString *)destination
	        handler:(id)handler
{
  NSDirectoryEnumerator	*enumerator;
  NSString *dirEntry;
  CREATE_AUTORELEASE_POOL(pool);
  
  enumerator = [self enumeratorAtPath: source];
  while ((dirEntry = [enumerator nextObject])) {
    NSString *sourceFile;
    NSString *fileType;
    NSString *destinationFile;
    NSDictionary *attributes;

    attributes = [enumerator fileAttributes];
    fileType = [attributes fileType];
    sourceFile = [source stringByAppendingPathComponent: dirEntry];
    destinationFile = [destination stringByAppendingPathComponent: dirEntry];

    [(id <FMProtocol>)self _sendToHandler: handler willProcessPath: sourceFile];

    if ([fileType isEqual: NSFileTypeDirectory]) {
      if ([self fileExistsAtPath: destinationFile]) {
        return NO;
      }
    
	    if (![self createDirectoryAtPath: destinationFile 
                            attributes: attributes]) {
        BOOL isdir; 
           
        if ([self fileExistsAtPath: destinationFile isDirectory: &isdir] && isdir) {
	        [enumerator skipDescendents];
	        if (![(id <FMProtocol>)self _copyPath: sourceFile
                                         toPath: destinationFile
                                        handler: handler]) {
		        return NO;
          }
        } else if (![(id <FMProtocol>)self _proceedAccordingToHandler: handler
					                                 forError: _lastError
					                                   inPath: destinationFile
					                                 fromPath: sourceFile
					                                   toPath: destinationFile]) {
          return NO;
        }
        
      } else {
	      [enumerator skipDescendents];
	      if (![(id <FMProtocol>)self _copyPath: sourceFile
                                       toPath: destinationFile
                                      handler: handler]) {
		      return NO;
        }
      }
      
	  } else if ([fileType isEqual: NSFileTypeRegular]) {
	    if (![(id <FMProtocol>)self _copyFile: sourceFile
			                               toFile: destinationFile
		                                handler: handler]) {
	      return NO;
      }
      
	  } else if ([fileType isEqual: NSFileTypeSymbolicLink]) {
	    NSString *path = [self pathContentOfSymbolicLinkAtPath: sourceFile];
      
	    if (![self createSymbolicLinkAtPath: destinationFile pathContent: path]) {
        if (![(id <FMProtocol>)self _proceedAccordingToHandler: handler
		                                forError: @"cannot create symbolic link"
		                                  inPath: sourceFile
		                                fromPath: sourceFile
		                                  toPath: destinationFile]) {
          return NO;
        }
	    }
      
	  } else {
	    NSString *s = [NSString stringWithFormat: @"cannot copy file type '%@'", fileType];
	  
      ASSIGN(_lastError, s);
	    NSLog(@"%@: %@", sourceFile, s);
	    continue;
	  }
    
    [self changeFileAttributes: attributes atPath: destinationFile];
  }
  
  RELEASE(pool);

  return YES;
}

@end
*/

@implementation OpProgressView

#define PROG_IND_MAX (-28)

- (void)dealloc
{
  RELEASE (image);
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect 
    refreshInterval:(float)refresh
{
  self = [super initWithFrame: frameRect];

  if (self) {
    NSBundle *bundle = [NSBundle bundleForClass: [Operation class]];
    NSString *path = [bundle pathForResource: @"progind" ofType: @"tiff"];
 
    image = [[NSImage alloc] initWithContentsOfFile: path];     
    rfsh = refresh;
    orx = PROG_IND_MAX;
  }

  return self;
}

- (void)start
{
  progTimer = [NSTimer scheduledTimerWithTimeInterval: rfsh 
						            target: self selector: @selector(animate:) 
																					userInfo: nil repeats: YES];
}

- (void)stop
{
  if (progTimer && [progTimer isValid]) {
    [progTimer invalidate];
  }
}

- (void)animate:(id)sender
{
  orx++;
  [self setNeedsDisplay: YES];
  
  if (orx == 0) {
    orx = PROG_IND_MAX;
  }
}

- (void)drawRect:(NSRect)rect
{
  [image compositeToPoint: NSMakePoint(orx, 2) 
                operation: NSCompositeSourceOver];
}

@end
