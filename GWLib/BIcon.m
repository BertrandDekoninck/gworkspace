/* BIcon.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "GWProtocol.h"
#include "GWFunctions.h"
#include "GWNotifications.h"
#include "GWLib.h"
#include "BIcon.h"
#include "BIconLabel.h"
#include "GNUstep.h"

#ifdef GNUSTEP 
  #define ARROW_POS_Y 26
  #define ARROW_MARGIN_X 11
#else
  #define ARROW_POS_Y 26
  #define ARROW_MARGIN_X 11
#endif

#define CHECK_LOCK if (locked) return
#define CHECK_LOCK_RET(x) if (locked) return x

@implementation BIcon

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
  TEST_RELEASE (paths);
  TEST_RELEASE (fullpath);
  TEST_RELEASE (name);
	TEST_RELEASE (hostname);
  TEST_RELEASE (type);
  TEST_RELEASE (icon);
	RELEASE (namelabel);
  RELEASE (highlight);
  RELEASE (arrow); 	
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
    NSArray *pbTypes = [NSArray arrayWithObjects: NSFilenamesPboardType, 
                                          GWRemoteFilenamesPboardType, nil];
    
    fm = [NSFileManager defaultManager];

    ASSIGN (highlight, [NSImage imageNamed: GWCellHighlightIconName]);
    ASSIGN (arrow, [NSImage imageNamed: @"common_3DArrowRight.tiff"]);

    namelabel = [[BIconLabel alloc] initForIcon: self];
		[namelabel setBezeled: NO];
		[namelabel setEditable: NO];
		[namelabel setSelectable: NO];
		[namelabel setAlignment: NSCenterTextAlignment];
    #ifdef GNUSTEP 
		  [namelabel setFont: [NSFont systemFontOfSize: 12]];
	    [namelabel setBackgroundColor: [NSColor windowBackgroundColor]];
		#else
		  [namelabel setFont: [NSFont systemFontOfSize: 11]];
	    [namelabel setBackgroundColor: [NSColor whiteColor]];
    #endif
    
    contestualMenu = [[GWLib workspaceApp] usesContestualMenu];
    
		paths = nil;
		fullpath = nil;
		hostname = nil;
    icon = nil;
    isbranch = NO;
    dimmed = NO;
		locked = NO;
		isPakage = NO;
    singlepath = YES;
    isSelect = NO;
    dragdelay = 0;
    isDragTarget = NO;
		onSelf = NO;
		isRootIcon = NO;
		
    [self registerForDraggedTypes: pbTypes];    
  }
  
  return self;
}

- (void)setPaths:(NSArray *)p
{
  float width, labwidth;
  int i, count;
	
  if ([p isEqualToArray: paths]) {
    return;
  }

  if (p == nil) {
    TEST_RELEASE (paths);
    paths = nil;
    TEST_RELEASE (fullpath);
		fullpath = nil;
		ASSIGN (name, @"");
    TEST_RELEASE (type);
    type = nil;
		isPakage = NO;
    TEST_RELEASE (icon);
    icon = nil;
		dimmed = YES;
		[self setNeedsDisplay: YES];
    return;
  }
	
	dimmed = NO;
	
  ASSIGN (paths, p);
  count = [paths count];                    

  if (count == 1) {
    singlepath = YES;   
    ASSIGN (fullpath, [paths objectAtIndex: 0]); 		
		if ([fullpath isEqualToString: fixPath(@"/", 0)]) {
			ASSIGN (name, fullpath);
			isRootIcon = YES;
		} else {
    	ASSIGN (name, [fullpath lastPathComponent]);
			isRootIcon = NO;
		}
    
    ASSIGN (type, [GWLib typeOfFileAt: fullpath]);
    isPakage = [GWLib isPakageAtPath: fullpath];    
		
  } else {
		fullpath = nil;
    singlepath = NO;
    ASSIGN (name, ([NSString stringWithFormat: @"%i items", count]));
    type = nil;
		isRootIcon = NO;
		isPakage = NO;
  }

  if (singlepath == YES) {
    ASSIGN (icon, [GWLib iconForFile: fullpath ofType: type]);    
  } else {
    ASSIGN (icon, [NSImage imageNamed: @"MultipleSelection.tiff"]);
  }

  width = [self frame].size.width;
  labwidth = [[namelabel font] widthOfString: name] + 8;
  if (labwidth > width) {
    labwidth = width;
  }
	[namelabel setFrame: NSMakeRect(0, 0, labwidth, 14)];  
	
	if (isRootIcon == NO) {
  	[namelabel setStringValue: cutFileLabelText(name, namelabel, labwidth)];
  } else {
		NSHost *host = [NSHost currentHost];
		NSString *hname = [host name];
		NSRange range = [hname rangeOfString: @"."];

		if (range.length != 0) {	
			hname = [hname substringToIndex: range.location];
		} 			
		ASSIGN (hostname, hname);
		[namelabel setStringValue: hostname];
	}

  [self setLocked: NO];
  
  for (i = 0; i < [paths count]; i++) {
    NSString *path = [paths objectAtIndex: i];

    if ([GWLib isLockedPath: path]) {
      [self setLocked: YES];
      break;
    }
  }
	
	[delegate icon: self setFrameOfLabel: namelabel];		
	[self setNeedsDisplay: YES];
}

- (void)setFrame:(NSRect)frameRect
{
  float width, labwidth;

  [super setFrame: frameRect];
  
  width = [self frame].size.width;
	
	if (isRootIcon == NO) {
  	labwidth = [[namelabel font] widthOfString: name] + 8;
  } else {
  	labwidth = [[namelabel font] widthOfString: hostname] + 8;
	}
  if (labwidth > width) {
    labwidth = width;
  }

  [namelabel setFrame: NSMakeRect(0, 0, labwidth, 14)];    

	if (isRootIcon == NO) {
		[namelabel setStringValue: cutFileLabelText(name, namelabel, labwidth)];
  } else {
		[namelabel setStringValue: hostname];
	}
 
	[delegate icon: self setFrameOfLabel: namelabel];
  
	[self setNeedsDisplay: YES];
}

- (void)select
{
  if (isSelect || dimmed) {
    return;
  }
  
	isSelect = YES;
	[namelabel setBackgroundColor: [NSColor whiteColor]]; 	
	[delegate unselectOtherIcons: self];
	[self setNeedsDisplay: YES];
  [namelabel setNeedsDisplay: YES];
}

- (void)unselect
{  
	isSelect = NO;

  #ifdef GNUSTEP 
	  [namelabel setBackgroundColor: [NSColor windowBackgroundColor]];
	#else
	  [namelabel setBackgroundColor: [NSColor whiteColor]];
  #endif
  
	[self setNeedsDisplay: YES];  
  [namelabel setNeedsDisplay: YES];
}

- (void)renewIcon
{
  if (singlepath == YES) {
    ASSIGN (icon, [GWLib iconForFile: fullpath ofType: type]);    
  } else {
    ASSIGN (icon, [NSImage imageNamed: @"MultipleSelection.tiff"]);
  }
  [self setNeedsDisplay: YES];
}

- (void)openWithApp:(id)sender
{
  NSString *appName = [[sender representedObject] objectForKey: @"appName"];
  NSString *fullPath = [[sender representedObject] objectForKey: @"fullPath"];

  [[NSWorkspace sharedWorkspace] openFile: fullPath withApplication: appName]; 
}

- (void)openWith:(id)sender
{
  [[GWLib workspaceApp] openSelectedPathsWith];
}

- (BOOL)isSelect
{
  return isSelect;
}

- (NSTextField *)label
{
  return namelabel;
}

- (void)setBranch:(BOOL)value
{
  if (isbranch != value) {
    isbranch = value;  
    [self setDimmed: NO];
	  [self setNeedsDisplay: YES];
  }
}

- (BOOL)isBranch
{
  return isbranch;
}

- (void)setDimmed:(BOOL)value
{
  if (dimmed != value) {
    dimmed = value;
  }
}

- (BOOL)isDimmed
{
  return dimmed;
}

- (void)setLocked:(BOOL)value
{
	if (locked == value) {
		return;
	}
	locked = value;
	[namelabel setTextColor: (locked ? [NSColor disabledControlTextColor] 
																							: [NSColor controlTextColor])];
	[self setNeedsDisplay: YES];		
	[namelabel setNeedsDisplay: YES];
}

- (BOOL)isLocked
{
	return locked;
}

- (BOOL)isRootIcon
{
	return isRootIcon;
}

- (NSArray *)paths
{
  return paths;
}

- (NSString *)name
{
  return name;
}

- (NSString *)hostname
{
	return hostname;
}

- (NSString *)type
{
  return type;
}

- (NSImage *)icon
{
  return icon;
}

- (NSSize)iconShift
{
	NSRect r = [self frame];
	NSSize s = [icon size];
	
	return NSMakeSize((r.size.width - s.width) / 2, (r.size.height - s.height) / 2);	
}

- (void)clickOnLabel
{
	CHECK_LOCK;
  [self select];
	[delegate clickOnIcon: self];
}

- (void)mouseUp:(NSEvent *)theEvent
{
  CHECK_LOCK;
	
	if([theEvent clickCount] > 1) {
		unsigned int modifier = [theEvent modifierFlags];		
		[delegate doubleClickOnIcon: self newViewer: (modifier == NSControlKeyMask)];
	}  
}

- (void)mouseDown:(NSEvent *)theEvent
{
	NSEvent *nextEvent;
  NSPoint location;
  NSSize offset;
  BOOL startdnd = NO;
	
	CHECK_LOCK;
		
	if (dimmed) {
		return;
	}
	
  location = [theEvent locationInWindow];
  location = [self convertPoint: location fromView: nil];
  
  if (ONICON(location, [self frame].size, [icon size]) == NO) {    
    return;  
  }

	if ([theEvent clickCount] == 1) {   
    if (isSelect == NO) {  
      [self select];
      [delegate unselectNameEditor];
    }

    while (1) {
	    nextEvent = [[self window] nextEventMatchingMask:
    							              NSLeftMouseUpMask | NSLeftMouseDraggedMask];

      if ([nextEvent type] == NSLeftMouseUp) {
			  [delegate clickOnIcon: self];
        break;

      } else if ([nextEvent type] == NSLeftMouseDragged) {
	      if(dragdelay < 5) {
          dragdelay++;
        } else {     
          NSPoint p = [nextEvent locationInWindow];
          
          p = [self convertPoint: p fromView: nil];
          offset = NSMakeSize(p.x - location.x, p.y - location.y); 
          startdnd = YES;        
          break;
        }
      }
    }

    if (startdnd == YES) {  
      [self startExternalDragOnEvent: nextEvent withMouseOffset: offset];    
    } 
  }              
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
  if (([theEvent type] != NSRightMouseDown) || (isSelect == NO)) {
    return [super menuForEvent: theEvent];
  } else if ([theEvent modifierFlags] == NSControlKeyMask) {
    return [super menuForEvent: theEvent];
  }
  if ((name == nil) || ([[name pathExtension] length] == 0)) {
    return [super menuForEvent: theEvent];
  }
  if (contestualMenu == NO) {
    return [super menuForEvent: theEvent];
  }
    
  if ((type == NSPlainFileType) || ([type isEqual: NSShellCommandFileType])) {
    NSMenu *menu = [[NSMenu alloc] initWithTitle: NSLocalizedString(@"Open with", @"")];
    NSString *ext = [name pathExtension];    
    NSDictionary *apps = [[NSWorkspace sharedWorkspace] infoForExtension: ext];
    NSEnumerator *app_enum = [[apps allKeys] objectEnumerator];
    NSMenuItem *menuItem;
    id key;
    
    while ((key = [app_enum nextObject])) {
      NSDictionary *dict = [apps objectForKey: key];
      NSString *role = [dict objectForKey: @"NSRole"];
      NSMutableDictionary *repObjDict = [NSMutableDictionary dictionary];

      menuItem = [NSMenuItem new];    
      
      if (role) {
        [menuItem setTitle: [NSString stringWithFormat: @"%@ - %@", key, role]];
      } else {
        [menuItem setTitle: [NSString stringWithFormat: @"%@", key]];
      }
      
      [menuItem setTarget: self];      
      [menuItem setAction: @selector(openWithApp:)];      
      [repObjDict setObject: key forKey: @"appName"];
      [repObjDict setObject: fullpath forKey: @"fullPath"];      
      [menuItem setRepresentedObject: repObjDict];            
      [menu addItem: menuItem];
      RELEASE (menuItem);
    }

    menuItem = [NSMenuItem new]; 
    [menuItem setTitle:  NSLocalizedString(@"Open with...", @"")];
    [menuItem setTarget: self];      
    [menuItem setAction: @selector(openWith:)];          
    [menu addItem: menuItem];
    RELEASE (menuItem);
    
    AUTORELEASE (menu);
    return menu;
  }
  
  return [super menuForEvent: theEvent];
}

/*
- (BOOL)shouldDelayWindowOrderingForEvent:(NSEvent *)theEvent

Overridden by subclasses to allow the user to drag images from the receiver without its window moving forward and possibly obscuring the
destination, and without activating the application. If this method returns YES, the normal window ordering and activation mechanism is delayed
(not necessarily prevented) until the next mouse-up event. If it returns NO then normal ordering and activation occurs. Never invoke this
method directly; it's invoked automatically for each mouse-down event directed at the NSView.

An NSView subclass that allows dragging should implement this method to return YES if theEvent, an initial mouse-down event, is potentially
the beginning of a dragging session or of some other context where window ordering isn't appropriate. This method is invoked before a
mouseDown: message for theEvent is sent. NSView's implementation returns NO.

If, after delaying window ordering, the receiver actually initiates a dragging session or similar operation, it should also send a
preventWindowOrdering message to NSApp, which completely prevents the window from ordering forward and the activation from becoming
active. preventWindowOrdering is sent automatically by NSView's dragImage:... and dragFile:... methods.
*/

- (BOOL)isSinglePath
{
  return singlepath;
}

- (id)delegate
{
  return delegate;
}

- (void)setDelegate:(id)aDelegate
{
  ASSIGN (delegate, aDelegate);
	AUTORELEASE (delegate);
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent 
{
  return YES;
}

- (void)drawRect:(NSRect)rect
{
	if (dimmed == YES) {    
		return;
	}
  	
	if(isSelect) {
		[highlight compositeToPoint: ICONPOSITION(rect.size, [highlight size]) 
                      operation: NSCompositeSourceOver];
	}
	
  if (icon != nil) {
		if (locked == NO) {	
			[icon compositeToPoint: ICONPOSITION(rect.size, [icon size]) 
                  operation: NSCompositeSourceOver];
		} else {						 								 
			[icon dissolveToPoint: ICONPOSITION(rect.size, [icon size]) fraction: 0.3];						 
		}
  }
  
  if (isbranch == YES) {
		[arrow compositeToPoint: NSMakePoint(rect.size.width - ARROW_MARGIN_X, ARROW_POS_Y)
                  operation: NSCompositeSourceOver];
  }
}

@end


@implementation BIcon (DraggingSource)

- (void)startExternalDragOnEvent:(NSEvent *)event
                 withMouseOffset:(NSSize)offset
{
  NSPasteboard *pb = [NSPasteboard pasteboardWithName: NSDragPboard];	
  NSPoint dragPoint;

  [self declareAndSetShapeOnPasteboard: pb];

  ICONCENTER (self, icon, dragPoint);
	      
  [self dragImage: icon
               at: dragPoint 
           offset: offset
            event: event
       pasteboard: pb
           source: self
        slideBack: [[GWLib workspaceApp] animateSlideBack]];
}

- (void)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb
{
  NSArray *dndtypes = [NSArray arrayWithObject: NSFilenamesPboardType];
  
  [pb declareTypes: dndtypes owner: nil];
    
  if ([pb setPropertyList: paths forType: NSFilenamesPboardType] == NO) {
    return;
  }
}

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag
{
  return NSDragOperationAll;
}

- (void)draggedImage:(NSImage *)anImage 
						 endedAt:(NSPoint)aPoint 
					 deposited:(BOOL)flag
{
	dragdelay = 0;
  onSelf = NO;
  [self setNeedsDisplay: YES];
  [delegate restoreSelectionAfterDndOfIcon: self];
}

@end


@implementation BIcon (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb;
  NSDragOperation sourceDragMask;
	NSArray *sourcePaths;
	NSString *fromPath;
  NSString *buff;
	NSString *iconPath;
	int i, count;

	CHECK_LOCK_RET (NSDragOperationNone);
	
	isDragTarget = NO;
	
  if ((([type isEqualToString: NSDirectoryFileType] == NO)
      && ([type isEqualToString: NSFilesystemFileType] == NO)) || isPakage) {
    return NSDragOperationNone;
  }

	pb = [sender draggingPasteboard];

  if ([[pb types] containsObject: NSFilenamesPboardType]) {
    sourcePaths = [pb propertyListForType: NSFilenamesPboardType]; 
       
  } else if ([[pb types] containsObject: GWRemoteFilenamesPboardType]) {
    NSData *pbData = [pb dataForType: GWRemoteFilenamesPboardType]; 
    NSDictionary *pbDict = [NSUnarchiver unarchiveObjectWithData: pbData];
    
    sourcePaths = [pbDict objectForKey: @"paths"];
  } else {
    return NSDragOperationNone;
  }
  
	count = [sourcePaths count];
	fromPath = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];

	if (count == 0) {
		return NSDragOperationNone;
  } 

	if ([fm isWritableFileAtPath: fullpath] == NO) {
		return NSDragOperationNone;
	}

  if ([paths isEqualToArray: sourcePaths]) {
    onSelf = YES;
  }

	if ([fullpath isEqualToString: fromPath]) {
		return NSDragOperationNone;
  }  

	for (i = 0; i < count; i++) {
		if ([fullpath isEqualToString: [sourcePaths objectAtIndex: i]]) {
		  return NSDragOperationNone;
		}
	}

	buff = [NSString stringWithString: fullpath];
	while (1) {
		for (i = 0; i < count; i++) {
			if ([buff isEqualToString: [sourcePaths objectAtIndex: i]]) {
 		    return NSDragOperationNone;
			}
		}
    if ([buff isEqualToString: fixPath(@"/", 0)] == YES) {
      break;
    }            
		buff = [buff stringByDeletingLastPathComponent];
	}

  isDragTarget = YES;

  iconPath =  [fullpath stringByAppendingPathComponent: @".opendir.tiff"];

  if ([fm isReadableFileAtPath: iconPath]) {
    NSImage *img = [[NSImage alloc] initWithContentsOfFile: iconPath];

    if (img) {
      ASSIGN (icon, img);
      RELEASE (img);
    } else {
      ASSIGN (icon, [NSImage imageNamed: GWOpenFolderIconName]);
    }      
  } else {
	  ASSIGN (icon, [NSImage imageNamed: GWOpenFolderIconName]);    
  }

  [self setNeedsDisplay: YES];   

	sourceDragMask = [sender draggingSourceOperationMask];

	if (sourceDragMask == NSDragOperationCopy) {
		return NSDragOperationCopy;
	} else if (sourceDragMask == NSDragOperationLink) {
		return NSDragOperationLink;
	} else {
		return NSDragOperationAll;
	}
    
  return NSDragOperationNone;
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSDragOperation sourceDragMask;

	CHECK_LOCK_RET (NSDragOperationNone);
	
	if (isPakage) {
		return NSDragOperationNone;
	}
	if (isDragTarget == NO) {
		return NSDragOperationNone;
	}

	sourceDragMask = [sender draggingSourceOperationMask];
	
	if (sourceDragMask == NSDragOperationCopy) {
		return NSDragOperationCopy;
	} else if (sourceDragMask == NSDragOperationLink) {
		return NSDragOperationLink;
	} else {
		return NSDragOperationAll;
	}

	return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  if(isDragTarget == YES) {
    isDragTarget = NO;  
		onSelf = NO;
    ASSIGN (icon, [GWLib iconForFile: fullpath ofType: type]); 
    [self setNeedsDisplay: YES];   
  }
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	CHECK_LOCK_RET (NO);
	return isDragTarget;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	CHECK_LOCK_RET (NO);
	return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb;
  NSDragOperation sourceDragMask;
	NSArray *sourcePaths;
  NSString *operation, *source;
  NSMutableArray *files;
	NSMutableDictionary *opDict;
	NSString *trashPath;
  int i;

	CHECK_LOCK;
	
	isDragTarget = NO;  

  if (onSelf == YES) {
    onSelf = NO;
    return;
  }

  ASSIGN (icon, [GWLib iconForFile: fullpath ofType: type]); 
  [self setNeedsDisplay: YES];

	sourceDragMask = [sender draggingSourceOperationMask];
  pb = [sender draggingPasteboard];
    
  if ([[pb types] containsObject: GWRemoteFilenamesPboardType]) {  
    NSData *pbData = [pb dataForType: GWRemoteFilenamesPboardType]; 

    [GWLib concludeRemoteFilesDragOperation: pbData
                                atLocalPath: fullpath];
    return;
  }
    
  sourcePaths = [pb propertyListForType: NSFilenamesPboardType];

  source = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];
  
	trashPath = [[GWLib workspaceApp] trashPath];

	if ([source isEqual: trashPath]) {
		operation = GWorkspaceRecycleOutOperation;
	} else {	
		if (sourceDragMask == NSDragOperationCopy) {
			operation = NSWorkspaceCopyOperation;
		} else if (sourceDragMask == NSDragOperationLink) {
			operation = NSWorkspaceLinkOperation;
		} else {
			operation = NSWorkspaceMoveOperation;
		}
  }
  
  files = [NSMutableArray arrayWithCapacity: 1];    
  for(i = 0; i < [sourcePaths count]; i++) {    
    [files addObject: [[sourcePaths objectAtIndex: i] lastPathComponent]];
  }  

	opDict = [NSMutableDictionary dictionaryWithCapacity: 4];
	[opDict setObject: operation forKey: @"operation"];
	[opDict setObject: source forKey: @"source"];
	[opDict setObject: fullpath forKey: @"destination"];
	[opDict setObject: files forKey: @"files"];

  [[GWLib workspaceApp] performFileOperationWithDictionary: opDict];
}

@end

