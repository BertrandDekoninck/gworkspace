/* FSNIconsView.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
 *
 * This file is part of the GNUstep FSNode framework
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
#include <math.h>
#include "FSNIconsView.h"
#include "FSNIcon.h"
#include "FSNFunctions.h"

#define DEF_ICN_SIZE 48
#define DEF_TEXT_SIZE 12
#define DEF_ICN_POS NSImageAbove

#define X_MARGIN (10)
#define Y_MARGIN (12)

#define EDIT_MARGIN (4)

#ifndef max
  #define max(a,b) ((a) >= (b) ? (a):(b))
#endif

#ifndef min
  #define min(a,b) ((a) <= (b) ? (a):(b))
#endif

#define CHECK_SIZE(s) \
if (s.width < 1) s.width = 1; \
if (s.height < 1) s.height = 1; \
if (s.width > maxr.size.width) s.width = maxr.size.width; \
if (s.height > maxr.size.height) s.height = maxr.size.height

#define SETRECT(o, x, y, w, h) { \
NSRect rct = NSMakeRect(x, y, w, h); \
if (rct.size.width < 0) rct.size.width = 0; \
if (rct.size.height < 0) rct.size.height = 0; \
[o setFrame: NSIntegralRect(rct)]; \
}

@implementation FSNIconsView

- (void)dealloc
{
  TEST_RELEASE (node);
  TEST_RELEASE (infoPath);
  TEST_RELEASE (nodeInfo);
  TEST_RELEASE (extInfoType);
  RELEASE (icons);
  RELEASE (labelFont);
  RELEASE (nameEditor);
  RELEASE (horizontalImage);
  RELEASE (verticalImage);
  TEST_RELEASE (lastSelection);
  TEST_RELEASE (charBuffer);
  RELEASE (backColor);
  RELEASE (textColor);
  RELEASE (disabledTextColor);
  
  [super dealloc];
}

- (id)init
{
  self = [super init];
    
  if (self) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
    NSString *appName = [defaults stringForKey: @"DesktopApplicationName"];
    NSString *selName = [defaults stringForKey: @"DesktopApplicationSelName"];
    id defentry;

    if (appName && selName) {
		  Class desktopAppClass = [[NSBundle mainBundle] classNamed: appName];
      SEL sel = NSSelectorFromString(selName);
      desktopApp = [desktopAppClass performSelector: sel];
    }
  
    defentry = [defaults dictionaryForKey: @"backcolor"];
    if (defentry) {
      float red = [[defentry objectForKey: @"red"] floatValue];
      float green = [[defentry objectForKey: @"green"] floatValue];
      float blue = [[defentry objectForKey: @"blue"] floatValue];
      float alpha = [[defentry objectForKey: @"alpha"] floatValue];
    
      ASSIGN (backColor, [NSColor colorWithCalibratedRed: red 
                                                   green: green 
                                                    blue: blue 
                                                   alpha: alpha]);
    } else {
      ASSIGN (backColor, [[NSColor windowBackgroundColor] colorUsingColorSpaceName: NSDeviceRGBColorSpace]);
    }

    defentry = [defaults dictionaryForKey: @"textcolor"];
    if (defentry) {
      float red = [[defentry objectForKey: @"red"] floatValue];
      float green = [[defentry objectForKey: @"green"] floatValue];
      float blue = [[defentry objectForKey: @"blue"] floatValue];
      float alpha = [[defentry objectForKey: @"alpha"] floatValue];
    
      ASSIGN (textColor, [NSColor colorWithCalibratedRed: red 
                                                   green: green 
                                                    blue: blue 
                                                   alpha: alpha]);
    } else {
      ASSIGN (textColor, [[NSColor controlTextColor] colorUsingColorSpaceName: NSDeviceRGBColorSpace]);
    }

    ASSIGN (disabledTextColor, [textColor highlightWithLevel: NSDarkGray]);
    
    defentry = [defaults objectForKey: @"iconsize"];
    iconSize = defentry ? [defentry intValue] : DEF_ICN_SIZE;

    defentry = [defaults objectForKey: @"labeltxtsize"];
    labelTextSize = defentry ? [defentry intValue] : DEF_TEXT_SIZE;
    ASSIGN (labelFont, [NSFont systemFontOfSize: labelTextSize]);
    
    defentry = [defaults objectForKey: @"iconposition"];
    iconPosition = defentry ? [defentry intValue] : DEF_ICN_POS;
        
    defentry = [defaults objectForKey: @"fsn_info_type"];
    infoType = defentry ? [defentry intValue] : FSNInfoNameType;
    extInfoType = nil;
    
    if (infoType == FSNInfoExtendedType) {
      defentry = [defaults objectForKey: @"extended_info_type"];

      if (defentry) {
        NSArray *availableTypes = [FSNodeRep availableExtendedInfoNames];
      
        if ([availableTypes containsObject: defentry]) {
          ASSIGN (extInfoType, defentry);
        }
      }
      
      if (extInfoType == nil) {
        infoType = FSNInfoNameType;
      }
    }

    [FSNodeRep setUseThumbnails: [defaults boolForKey: @"use_thumbnails"]];
    
    icons = [NSMutableArray new];
        
    nameEditor = [FSNIconNameEditor new];
    [nameEditor setDelegate: self];  
		[nameEditor setFont: labelFont];
		[nameEditor setBezeled: NO];
		[nameEditor setAlignment: NSCenterTextAlignment];
	  [nameEditor setBackgroundColor: backColor];
	  [nameEditor setTextColor: textColor];
    editIcon = nil;
    
    isDragTarget = NO;
		lastKeyPressed = 0.;
    charBuffer = nil;
    selectionMask = NSSingleSelectionMask;

    [self calculateGridSize];
    
    [self registerForDraggedTypes: [NSArray arrayWithObjects: 
                                                NSFilenamesPboardType, 
                                                @"GWRemoteFilenamesPboardType", 
                                                nil]];    
  }
   
  return self;
}

- (void)sortIcons
{
  SEL compSel = [FSNodeRep compareSelectorForDirectory: [node path]];
  NSArray *sorted = [icons sortedArrayUsingSelector: compSel];

  if (infoType == FSNInfoExtendedType) {
    NSArray *extsorted = [sorted sortedArrayUsingFunction: (int (*)(id, id, void*))compareWithExtType
                                                  context: (void *)NULL];
    sorted = extsorted;
  }
  
  [icons removeAllObjects];
  [icons addObjectsFromArray: sorted];
}

- (NSDictionary *)readNodeInfo
{
  NSDictionary *nodeDict = nil;
  
  ASSIGN (infoPath, [[node path] stringByAppendingPathComponent: @".dirinfo"]);
  
  if ([[NSFileManager defaultManager] fileExistsAtPath: infoPath]) {
    nodeDict = [NSDictionary dictionaryWithContentsOfFile: infoPath];

    if (nodeDict) {
      id entry = [nodeDict objectForKey: @"backcolor"];
      
      if (entry) {
        float red = [[entry objectForKey: @"red"] floatValue];
        float green = [[entry objectForKey: @"green"] floatValue];
        float blue = [[entry objectForKey: @"blue"] floatValue];
        float alpha = [[entry objectForKey: @"alpha"] floatValue];

        ASSIGN (backColor, [NSColor colorWithCalibratedRed: red 
                                                     green: green 
                                                      blue: blue 
                                                     alpha: alpha]);
      }

      entry = [nodeDict objectForKey: @"textcolor"];
      
      if (entry) {
        float red = [[entry objectForKey: @"red"] floatValue];
        float green = [[entry objectForKey: @"green"] floatValue];
        float blue = [[entry objectForKey: @"blue"] floatValue];
        float alpha = [[entry objectForKey: @"alpha"] floatValue];

        ASSIGN (textColor, [NSColor colorWithCalibratedRed: red 
                                                     green: green 
                                                      blue: blue 
                                                     alpha: alpha]);
                                                     
        ASSIGN (disabledTextColor, [textColor highlightWithLevel: NSDarkGray]);      
      }

      entry = [nodeDict objectForKey: @"iconsize"];
      iconSize = entry ? [entry intValue] : iconSize;

      entry = [nodeDict objectForKey: @"labeltxtsize"];
      if (entry) {
        labelTextSize = [entry intValue];
        ASSIGN (labelFont, [NSFont systemFontOfSize: labelTextSize]);      
      }

      entry = [nodeDict objectForKey: @"iconposition"];
      iconPosition = entry ? [entry intValue] : iconPosition;

      entry = [nodeDict objectForKey: @"fsn_info_type"];
      infoType = entry ? [entry intValue] : infoType;

      if (infoType == FSNInfoExtendedType) {
        DESTROY (extInfoType);
        entry = [nodeDict objectForKey: @"ext_info_type"];

        if (entry) {
          NSArray *availableTypes = [FSNodeRep availableExtendedInfoNames];

          if ([availableTypes containsObject: entry]) {
            ASSIGN (extInfoType, entry);
          }
        }

        if (extInfoType == nil) {
          infoType = FSNInfoNameType;
        }
      }
    }
  }
    
  if (nodeDict) {
    nodeInfo = [nodeDict mutableCopy];
  } else {
    nodeInfo = [NSMutableDictionary new];
  }
    
  return nodeDict;
}

- (void)updateNodeInfo
{
  if ([node isWritable]) {
    NSMutableDictionary *backColorDict = [NSMutableDictionary dictionary];
    NSMutableDictionary *txtColorDict = [NSMutableDictionary dictionary];
    float red, green, blue, alpha;
	
    [backColor getRed: &red green: &green blue: &blue alpha: &alpha];
    [backColorDict setObject: [NSNumber numberWithFloat: red] forKey: @"red"];
    [backColorDict setObject: [NSNumber numberWithFloat: green] forKey: @"green"];
    [backColorDict setObject: [NSNumber numberWithFloat: blue] forKey: @"blue"];
    [backColorDict setObject: [NSNumber numberWithFloat: alpha] forKey: @"alpha"];

    [nodeInfo setObject: backColorDict forKey: @"backcolor"];

    [textColor getRed: &red green: &green blue: &blue alpha: &alpha];
    [txtColorDict setObject: [NSNumber numberWithFloat: red] forKey: @"red"];
    [txtColorDict setObject: [NSNumber numberWithFloat: green] forKey: @"green"];
    [txtColorDict setObject: [NSNumber numberWithFloat: blue] forKey: @"blue"];
    [txtColorDict setObject: [NSNumber numberWithFloat: alpha] forKey: @"alpha"];

    [nodeInfo setObject: txtColorDict forKey: @"textcolor"];
    
    [nodeInfo setObject: [NSNumber numberWithInt: iconSize] 
                 forKey: @"iconsize"];

    [nodeInfo setObject: [NSNumber numberWithInt: labelTextSize] 
                 forKey: @"labeltxtsize"];

    [nodeInfo setObject: [NSNumber numberWithInt: iconPosition] 
                 forKey: @"iconposition"];

    [nodeInfo setObject: [NSNumber numberWithInt: infoType] 
                 forKey: @"fsn_info_type"];

    if (infoType == FSNInfoExtendedType) {
      [nodeInfo setObject: extInfoType forKey: @"ext_info_type"];
    }
    
    [nodeInfo writeToFile: infoPath atomically: YES];
  }
}

- (void)calculateGridSize
{
  NSSize highlightSize = NSZeroSize;
  NSSize labelSize = NSZeroSize;
  
  highlightSize.width = ceil(iconSize / 3 * 4);
  highlightSize.height = ceil(highlightSize.width * [FSNodeRep highlightHeightFactor]);
  if ((highlightSize.height - iconSize) < 4) {
    highlightSize.height = iconSize + 4;
  }

  labelSize.height = floor([labelFont defaultLineHeightForFont]);
  labelSize.width = [FSNodeRep labelWFactor] * labelTextSize;

  gridSize.height = highlightSize.height;

  if (iconPosition == NSImageAbove) {
    gridSize.height += labelSize.height;
    gridSize.width = labelSize.width;
  } else {
    gridSize.width = highlightSize.width + labelSize.width + [FSNodeRep labelMargin];
  }
}

- (void)tile
{
  CREATE_AUTORELEASE_POOL (pool);
  NSRect svr = [[self superview] frame];
  NSRect r = [self frame];
  NSRect maxr = [[NSScreen mainScreen] frame];
	float px = 0 - gridSize.width;
  float py = gridSize.height + Y_MARGIN;
  NSSize sz;
  int poscount = 0;
	int count = [icons count];
	NSRect *irects = NSZoneMalloc (NSDefaultMallocZone(), sizeof(NSRect) * count);
  NSCachedImageRep *rep = nil;
  NSArray *selection;
  int i;

  colcount = 0;
  
	for (i = 0; i < count; i++) {
    px += (gridSize.width + X_MARGIN);      
    
    if (px >= (svr.size.width - gridSize.width)) {
      px = X_MARGIN; 
      py += (gridSize.height + Y_MARGIN);  

      if (colcount < poscount) { 
        colcount = poscount; 
      } 
      poscount = 0;    
    }
    
		poscount++;

		irects[i] = NSMakeRect(px, py, gridSize.width, gridSize.height);		
	}

	py += Y_MARGIN;  
  py = (py < svr.size.height) ? svr.size.height : py;

  SETRECT (self, r.origin.x, r.origin.y, svr.size.width, py);

	for (i = 0; i < count; i++) {   
		FSNIcon *icon = [icons objectAtIndex: i];
    
		irects[i].origin.y = py - irects[i].origin.y;
    irects[i] = NSIntegralRect(irects[i]);
    
    if (NSEqualRects(irects[i], [icon frame]) == NO) {
      [icon setFrame: irects[i]];
    }
    
    [icon setGridIndex: i];
	}

  DESTROY (horizontalImage);
  sz = NSMakeSize(svr.size.width, 2);
  CHECK_SIZE (sz);
  horizontalImage = [[NSImage allocWithZone: (NSZone *)[(NSObject *)self zone]] 
                               initWithSize: sz];

  rep = [[NSCachedImageRep allocWithZone: (NSZone *)[(NSObject *)self zone]]
                            initWithSize: sz
                                   depth: [NSWindow defaultDepthLimit] 
                                separate: YES 
                                   alpha: YES];

  [horizontalImage addRepresentation: rep];
  RELEASE (rep);

  DESTROY (verticalImage);
  sz = NSMakeSize(2, py);
  CHECK_SIZE (sz);
  verticalImage = [[NSImage allocWithZone: (NSZone *)[(NSObject *)self zone]] 
                             initWithSize: sz];

  rep = [[NSCachedImageRep allocWithZone: (NSZone *)[(NSObject *)self zone]]
                            initWithSize: sz
                                   depth: [NSWindow defaultDepthLimit] 
                                separate: YES 
                                   alpha: YES];

  [verticalImage addRepresentation: rep];
  RELEASE (rep);
 
	NSZoneFree (NSDefaultMallocZone(), irects);
  
  RELEASE (pool);
  
  [self updateNameEditor];
  
  selection = [self selectedReps];
  if ([selection count]) {
    [self scrollIconToVisible: [selection objectAtIndex: 0]];
  } 
}

- (void)scrollIconToVisible:(FSNIcon *)icon
{
  NSRect irect = [icon frame];  
  float border = floor(irect.size.height * 0.2);
        
  irect.origin.y -= border;
  irect.size.height += border * 2;
  [self scrollRectToVisible: irect];	
}

- (NSString *)selectIconWithPrefix:(NSString *)prefix
{
	int i;

	for (i = 0; i < [icons count]; i++) {
		FSNIcon *icon = [icons objectAtIndex: i];
    NSString *name = [icon shownInfo];
    
		if ([name hasPrefix: prefix]) {
      [icon select];
      [self scrollIconToVisible: icon];
      
			return name;
		}
	}
  
  return nil;
}

- (void)selectIconInPrevLine
{
	FSNIcon *icon;
	int i, pos = -1;
  
	for (i = 0; i < [icons count]; i++) {
		icon = [icons objectAtIndex: i];
    
		if ([icon isSelected]) {
			pos = i - colcount;
			break;
		}
	}
  
	if (pos >= 0) {
		icon = [icons objectAtIndex: pos];
		[icon select];
    [self scrollIconToVisible: icon];
	}
}

- (void)selectIconInNextLine
{
	FSNIcon *icon;
	int i, pos = [icons count];
    
	for (i = 0; i < [icons count]; i++) {
		icon = [icons objectAtIndex: i];
    
		if ([icon isSelected]) {
			pos = i + colcount;
			break;
		}
	}
  
	if (pos <= ([icons count] -1)) {
		icon = [icons objectAtIndex: pos];
		[icon select];
    [self scrollIconToVisible: icon];
	}
}

- (void)selectPrevIcon
{
	int i;
    
	for (i = 0; i < [icons count]; i++) {
		FSNIcon *icon = [icons objectAtIndex: i];
    
		if ([icon isSelected]) {
			if (i > 0) {
        icon = [icons objectAtIndex: i - 1];  
        [icon select];
        [self scrollIconToVisible: icon];
			} 
      break;
		}
	}
}

- (void)selectNextIcon
{
  int count = [icons count];
	int i;
    
	for (i = 0; i < count; i++) {
		FSNIcon *icon = [icons objectAtIndex: i];
    
		if ([icon isSelected]) {
			if (i < (count - 1)) {
				icon = [icons objectAtIndex: i + 1];
        [icon select];
        [self scrollIconToVisible: icon];
			} 
      break;
		}
	} 
}

- (void)mouseUp:(NSEvent *)theEvent
{
  [self setSelectionMask: NSSingleSelectionMask];        
}

- (void)mouseDown:(NSEvent *)theEvent
{
  [self stopRepNameEditing];

  if ([theEvent modifierFlags] != NSShiftKeyMask) {
    selectionMask = NSSingleSelectionMask;
    selectionMask |= FSNCreatingSelectionMask;
		[self unselectOtherReps: nil];
    selectionMask = NSSingleSelectionMask;
    
    DESTROY (lastSelection);
    [self selectionDidChange];
	}
}

- (void)mouseDragged:(NSEvent *)theEvent
{
  unsigned int eventMask = NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSPeriodicMask;
  NSDate *future = [NSDate distantFuture];
  NSPoint	startp, sp;
  NSPoint	p, pp;
  NSRect visibleRect;
  NSRect oldRect; 
  NSRect r, wr;
  NSRect selrect;
  float x, y, w, h;
  int i;
  
#define scrollPointToVisible(p) \
{ \
NSRect sr; \
sr.origin = p; \
sr.size.width = sr.size.height = 1.0; \
[self scrollRectToVisible: sr]; \
}

#define CONVERT_CHECK \
pp = [self convertPoint: p fromView: nil]; \
if (pp.x < 1) \
pp.x = 1; \
if (pp.x >= NSMaxX([self bounds])) \
pp.x = NSMaxX([self bounds]) - 1

  p = [theEvent locationInWindow];
  sp = [self convertPoint: p  fromView: nil];
  startp = [self convertPoint: p fromView: nil];
  
  oldRect = NSZeroRect;  

	[[self window] disableFlushWindow];
  [self lockFocus];

  [NSEvent startPeriodicEventsAfterDelay: 0.02 withPeriod: 0.05];

  while ([theEvent type] != NSLeftMouseUp) {
    CREATE_AUTORELEASE_POOL (arp);

    theEvent = [NSApp nextEventMatchingMask: eventMask
                                  untilDate: future
                                     inMode: NSEventTrackingRunLoopMode
                                    dequeue: YES];

    if ([theEvent type] != NSPeriodic) {
      p = [theEvent locationInWindow];
    }
    
    CONVERT_CHECK;
    
    visibleRect = [self visibleRect];
    
    if ([self mouse: pp inRect: [self visibleRect]] == NO) {
      scrollPointToVisible(pp);
      CONVERT_CHECK;
      visibleRect = [self visibleRect];
    }

    if ((sp.y < visibleRect.origin.y)
          || (sp.y > (visibleRect.origin.y + visibleRect.size.height))) {
      if (sp.y < visibleRect.origin.y) {
        sp.y = visibleRect.origin.y - 1;
      }
      if (sp.y > (visibleRect.origin.y + visibleRect.size.height)) {
        sp.y = (visibleRect.origin.y + visibleRect.size.height + 1);
      }
    } 

    x = (pp.x >= sp.x) ? sp.x : pp.x;
    y = (pp.y >= sp.y) ? sp.y : pp.y;
    w = max(pp.x, sp.x) - min(pp.x, sp.x);
    w = (w == 0) ? 1 : w;
    h = max(pp.y, sp.y) - min(pp.y, sp.y);
    h = (h == 0) ? 1 : h;

    r = NSMakeRect(x, y, w, h);
    
    if (NSEqualRects(visibleRect, [self frame])) {
      r = NSIntersectionRect(r, visibleRect);
    }
    
    wr = [self convertRect: r toView: nil];
  
    sp = startp;

    if (NSEqualRects(oldRect, NSZeroRect) == NO) {
		  [verticalImage compositeToPoint: NSMakePoint(NSMinX(oldRect), NSMinY(oldRect))
		                         fromRect: NSMakeRect(0.0, 0.0, 1.0, oldRect.size.height)
		                        operation: NSCompositeCopy];

		  [verticalImage compositeToPoint: NSMakePoint(NSMaxX(oldRect)-1, NSMinY(oldRect))
		                         fromRect: NSMakeRect(1.0, 0.0, 1.0, oldRect.size.height)
		                        operation: NSCompositeCopy];

		  [horizontalImage compositeToPoint: NSMakePoint(NSMinX(oldRect), NSMinY(oldRect))
		                           fromRect: NSMakeRect(0.0, 0.0, oldRect.size.width, 1.0)
		                          operation: NSCompositeCopy];

      [horizontalImage compositeToPoint: NSMakePoint(NSMinX(oldRect), NSMaxY(oldRect)-1)
		                           fromRect: NSMakeRect(0.0, 1.0, oldRect.size.width, 1.0)
		                          operation: NSCompositeCopy];
    }
    [self displayIfNeeded];

    [verticalImage lockFocus];
    NSCopyBits([[self window] gState], 
            NSMakeRect(NSMinX(wr), NSMinY(wr), 
                          1.0, r.size.height),
			                          NSMakePoint(0.0, 0.0));
    NSCopyBits([[self window] gState],
			      NSMakeRect(NSMaxX(wr) -1, NSMinY(wr),
				                  1.0, r.size.height),
			                          NSMakePoint(1.0, 0.0));
    [verticalImage unlockFocus];

    [horizontalImage lockFocus];
    NSCopyBits([[self window] gState],
			      NSMakeRect(NSMinX(wr), NSMinY(wr),
				                  r.size.width, 1.0),
			                          NSMakePoint(0.0, 0.0));
    NSCopyBits([[self window] gState],
			      NSMakeRect(NSMinX(wr), NSMaxY(wr) -1,
				                  r.size.width, 1.0),
			                          NSMakePoint(0.0, 1.0));
    [horizontalImage unlockFocus];

    [[NSColor darkGrayColor] set];
    NSFrameRect(r);
    oldRect = r;

    [[self window] enableFlushWindow];
    [[self window] flushWindow];
    [[self window] disableFlushWindow];

    DESTROY (arp);
  }
  
  [NSEvent stopPeriodicEvents];
  [[self window] postEvent: theEvent atStart: NO];
  
  if (NSEqualRects(oldRect, NSZeroRect) == NO) {
		[verticalImage compositeToPoint: NSMakePoint(NSMinX(oldRect), NSMinY(oldRect))
		                       fromRect: NSMakeRect(0.0, 0.0, 1.0, oldRect.size.height)
		                      operation: NSCompositeCopy];

		[verticalImage compositeToPoint: NSMakePoint(NSMaxX(oldRect)-1, NSMinY(oldRect))
		                       fromRect: NSMakeRect(1.0, 0.0, 1.0, oldRect.size.height)
		                      operation: NSCompositeCopy];

		[horizontalImage compositeToPoint: NSMakePoint(NSMinX(oldRect), NSMinY(oldRect))
		                         fromRect: NSMakeRect(0.0, 0.0, oldRect.size.width, 1.0)
		                        operation: NSCompositeCopy];

    [horizontalImage compositeToPoint: NSMakePoint(NSMinX(oldRect), NSMaxY(oldRect)-1)
		                         fromRect: NSMakeRect(0.0, 1.0, oldRect.size.width, 1.0)
		                        operation: NSCompositeCopy];
  }
  
  [[self window] enableFlushWindow];
  [[self window] flushWindow];
  [self unlockFocus];

  selectionMask = FSNMultipleSelectionMask;
  selectionMask |= FSNCreatingSelectionMask;

  x = (pp.x >= startp.x) ? startp.x : pp.x;
  y = (pp.y >= startp.y) ? startp.y : pp.y;
  w = max(pp.x, startp.x) - min(pp.x, startp.x);
  w = (w == 0) ? 1 : w;
  h = max(pp.y, startp.y) - min(pp.y, startp.y);
  h = (h == 0) ? 1 : h;

  selrect = NSMakeRect(x, y, w, h);
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    NSRect iconBounds = [self convertRect: [icon iconBounds] fromView: icon];

    if (NSIntersectsRect(selrect, iconBounds)) {
      [icon select];
    } 
  }  
  
  selectionMask = NSSingleSelectionMask;
  
  [self selectionDidChange];
}

- (void)keyDown:(NSEvent *)theEvent 
{
  NSString *characters = [theEvent characters];  
  unichar character;
	NSRect vRect, hiddRect;
	NSPoint p;
	float x, y, w, h;

	characters = [theEvent characters];
	character = 0;
		
  if ([characters length] > 0) {
		character = [characters characterAtIndex: 0];
	}
	
  switch (character) {
    case NSPageUpFunctionKey:
		  vRect = [self visibleRect];
		  p = vRect.origin;    
		  x = p.x;
		  y = p.y + vRect.size.height;
		  w = vRect.size.width;
		  h = vRect.size.height;
		  hiddRect = NSMakeRect(x, y, w, h);
		  [self scrollRectToVisible: hiddRect];
	    return;

    case NSPageDownFunctionKey:
		  vRect = [self visibleRect];
		  p = vRect.origin;
		  x = p.x;
		  y = p.y - vRect.size.height;
		  w = vRect.size.width;
		  h = vRect.size.height;
		  hiddRect = NSMakeRect(x, y, w, h);
		  [self scrollRectToVisible: hiddRect];
	    return;

    case NSUpArrowFunctionKey:
	    [self selectIconInPrevLine];
      return;

    case NSDownArrowFunctionKey:
	    [self selectIconInNextLine];
      return;

    case NSLeftArrowFunctionKey:
			{
				if ([theEvent modifierFlags] & NSControlKeyMask) {
	      	[super keyDown: theEvent];
	    	} else {
	    		[self selectPrevIcon];
				}
			}
      return;

    case NSRightArrowFunctionKey:
			{
				if ([theEvent modifierFlags] & NSControlKeyMask) {
	      	[super keyDown: theEvent];
	    	} else {
	    		[self selectNextIcon];
				}
			}
	  	return;
      
    case 13:
      [desktopApp openSelectionInNewViewer: NO];
      return;

    default:    
      break;
  }

  if ((character < 0xF700) && ([characters length] > 0)) {
		SEL icnwpSel = @selector(selectIconWithPrefix:);
		IMP icnwp = [self methodForSelector: icnwpSel];
    
    if (charBuffer == nil) {
      charBuffer = [characters substringToIndex: 1];
      RETAIN (charBuffer);
      lastKeyPressed = 0.;
    } else {
      if ([theEvent timestamp] - lastKeyPressed < 2000.0) {
        ASSIGN (charBuffer, ([charBuffer stringByAppendingString:
				    															[characters substringToIndex: 1]]));
      } else {
        ASSIGN (charBuffer, ([characters substringToIndex: 1]));
        lastKeyPressed = 0.;
      }														
    }	
    		
    lastKeyPressed = [theEvent timestamp];

    if ((*icnwp)(self, icnwpSel, charBuffer)) {
      return;
    }
  }
  
  [super keyDown: theEvent];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
  NSArray *selnodes;
  NSMenu *menu;
  NSMenuItem *menuItem;
  NSString *firstext; 
  NSDictionary *apps;
  NSEnumerator *app_enum;
  id key; 
  int i;

  if ([theEvent modifierFlags] == NSControlKeyMask) {
    return [super menuForEvent: theEvent];
  } 

  selnodes = [self selectedNodes];

  if ([selnodes count]) {
    NSAutoreleasePool *pool;

    firstext = [[[selnodes objectAtIndex: 0] path] pathExtension];

    for (i = 0; i < [selnodes count]; i++) {
      FSNode *snode = [selnodes objectAtIndex: i];
      NSString *selpath = [snode path];
      NSString *ext = [selpath pathExtension];   

      if ([ext isEqual: firstext] == NO) {
        return [super menuForEvent: theEvent];  
      }

      if ([snode isDirectory] == NO) {
        if ([snode isPlain] == NO) {
          return [super menuForEvent: theEvent];
        }
      } else {
        if (([snode isPackage] == NO) || [snode isApplication]) {
          return [super menuForEvent: theEvent];
        } 
      }
    }
    
    menu = [[NSMenu alloc] initWithTitle: NSLocalizedString(@"Open with", @"")];
    apps = [[NSWorkspace sharedWorkspace] infoForExtension: firstext];
    app_enum = [[apps allKeys] objectEnumerator];

    pool = [NSAutoreleasePool new];

    while ((key = [app_enum nextObject])) {
      menuItem = [NSMenuItem new];    
      key = [key stringByDeletingPathExtension];
      [menuItem setTitle: key];
      [menuItem setTarget: desktopApp];      
      [menuItem setAction: @selector(openSelectionWithApp:)];      
      [menuItem setRepresentedObject: key];            
      [menu addItem: menuItem];
      RELEASE (menuItem);
    }

    RELEASE (pool);
    
    return [menu autorelease];
  }
   
  return [super menuForEvent: theEvent]; 
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldFrameSize
{
  [self tile];
}

- (void)viewDidMoveToSuperview
{
  [super viewDidMoveToSuperview];

  if ([self superview]) {
    [[self window] setBackgroundColor: backColor];
  }
}

- (void)drawRect:(NSRect)rect
{  
  [super drawRect: rect];
  [backColor set];
  NSRectFill(rect);
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
  return YES;
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

@end


@implementation FSNIconsView (NodeRepContainer)

- (void)showContentsOfNode:(FSNode *)anode
{
  NSArray *subNodes = [anode subNodes];
  NSMutableArray *unsorted = [NSMutableArray array];
  SEL compSel;
  NSArray *sorted;
  int i;

  for (i = 0; i < [icons count]; i++) {
    [[icons objectAtIndex: i] removeFromSuperview];
  }
  [icons removeAllObjects];
  editIcon = nil;
    
  ASSIGN (node, anode);
  [self readNodeInfo];
    
  for (i = 0; i < [subNodes count]; i++) {
    FSNode *subnode = [subNodes objectAtIndex: i];
    FSNIcon *icon = [[FSNIcon alloc] initForNode: subnode
                                    nodeInfoType: infoType
                                    extendedType: extInfoType
                                        iconSize: iconSize
                                    iconPosition: iconPosition
                                       labelFont: labelFont
                                       textColor: textColor
                                       gridIndex: -1
                                       dndSource: YES
                                       acceptDnd: YES];
    [unsorted addObject: icon];
    [self addSubview: icon];
    RELEASE (icon);
  }

  compSel = [FSNodeRep compareSelectorForDirectory: [node path]];
  sorted = [unsorted sortedArrayUsingSelector: compSel];
  [icons addObjectsFromArray: sorted];
  
  [self tile];
  
  DESTROY (lastSelection);
  [self selectionDidChange];
}

- (void)reloadContents
{
  NSArray *selection = [self selectedNodes];
  NSMutableArray *opennodes = [NSMutableArray array];
  int i;
            
  RETAIN (selection);
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];

    if ([icon isOpened]) {
      [opennodes addObject: [icon node]];
    }
  }
  
  RETAIN (opennodes);

  [self showContentsOfNode: node];

  selectionMask = FSNMultipleSelectionMask;
  selectionMask |= FSNCreatingSelectionMask;

  for (i = 0; i < [selection count]; i++) {
    FSNode *nd = [selection objectAtIndex: i]; 
    
    if ([nd isValid]) { 
      FSNIcon *icon = [self repOfSubnode: nd];
      
      if (icon) {
        [icon select];
      }
    }
  }

  selectionMask = NSSingleSelectionMask;

  RELEASE (selection);

  for (i = 0; i < [opennodes count]; i++) {
    FSNode *nd = [opennodes objectAtIndex: i]; 
    
    if ([nd isValid]) { 
      FSNIcon *icon = [self repOfSubnode: nd];
      
      if (icon) {
        [icon setOpened: YES];
      }
    }
  }
  
  RELEASE (opennodes);
    
  [self checkLockedReps];
  [self tile];

  selection = [self selectedReps];
  
  if ([selection count]) {
    [self scrollIconToVisible: [selection objectAtIndex: 0]];
  }

  [self selectionDidChange];
}

- (void)reloadFromNode:(FSNode *)anode
{
  if ([node isEqual: anode]) {
    [self reloadContents];
    
  } else if ([node isSubnodeOfNode: anode]) {
    NSArray *components = [FSNode nodeComponentsFromNode: anode toNode: node];
    int i;
  
    for (i = 0; i < [components count]; i++) {
      FSNode *component = [components objectAtIndex: i];
    
      if ([component isValid] == NO) {
        component = [FSNode nodeWithRelativePath: [component parentPath]
                                          parent: nil];
        [self showContentsOfNode: component];
        break;
      }
    }
  }
}

- (FSNode *)baseNode
{
  return node;
}

- (FSNode *)shownNode
{
  return node;
}

- (BOOL)isSingleNode
{
  return YES;
}

- (BOOL)isShowingNode:(FSNode *)anode
{
  return ([node isEqual: anode] ? YES : NO);
}

- (BOOL)isShowingPath:(NSString *)path
{
  return ([[node path] isEqual: path] ? YES : NO);
}

- (void)sortTypeChangedAtPath:(NSString *)path
{
  if ((path == nil) || [[node path] isEqual: path]) {
    [self reloadContents];
  }
}

- (void)nodeContentsWillChange:(NSDictionary *)info
{
  [self checkLockedReps];
}

- (void)nodeContentsDidChange:(NSDictionary *)info
{
  NSString *operation = [info objectForKey: @"operation"];
  NSString *source = [info objectForKey: @"source"];
  NSString *destination = [info objectForKey: @"destination"];
  NSArray *files = [info objectForKey: @"files"];
  NSString *ndpath = [node path];
  int i; 

  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    files = [NSArray arrayWithObject: [source lastPathComponent]];
    source = [source stringByDeletingLastPathComponent]; 
  }

  if (([ndpath isEqual: source] == NO) && ([ndpath isEqual: destination] == NO)) {
    [self reloadContents];
    return;
  }

  if ([ndpath isEqual: source]) {
    if ([operation isEqual: @"NSWorkspaceMoveOperation"]
              || [operation isEqual: @"NSWorkspaceDestroyOperation"]
              || [operation isEqual: @"GWorkspaceRenameOperation"]
			        || [operation isEqual: @"GWorkspaceRecycleOutOperation"]) {
      for (i = 0; i < [files count]; i++) {
        NSString *fname = [files objectAtIndex: i];
        FSNode *subnode = [FSNode nodeWithRelativePath: fname parent: node];
        [self removeRepOfSubnode: subnode];
      }
    } else if ([operation isEqual: @"NSWorkspaceRecycleOperation"]) {
      [self reloadContents];
      return;
    }
  }
  
  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    files = [NSArray arrayWithObject: [destination lastPathComponent]];
    destination = [destination stringByDeletingLastPathComponent]; 
  }

  if ([ndpath isEqual: destination]
          && ([operation isEqual: @"NSWorkspaceMoveOperation"]   
              || [operation isEqual: @"NSWorkspaceCopyOperation"]
              || [operation isEqual: @"NSWorkspaceLinkOperation"]
              || [operation isEqual: @"NSWorkspaceDuplicateOperation"]
              || [operation isEqual: @"GWorkspaceCreateDirOperation"]
              || [operation isEqual: @"GWorkspaceCreateFileOperation"]
              || [operation isEqual: @"GWorkspaceRenameOperation"]
				      || [operation isEqual: @"GWorkspaceRecycleOutOperation"])) { 
    for (i = 0; i < [files count]; i++) {
      NSString *fname = [files objectAtIndex: i];
      FSNode *subnode = [FSNode nodeWithRelativePath: fname parent: node];
      FSNIcon *icon = [self repOfSubnode: subnode];
      
      if (icon) {
        [icon setNode: subnode];
      } else {
        [self addRepForSubnode: subnode];
      }
    }
    
    [self sortIcons];
  }
  
  [self checkLockedReps];
  [self tile];
  [self setNeedsDisplay: YES];  
  [self selectionDidChange];
}

- (void)watchedPathChanged:(NSDictionary *)info
{
  NSString *event = [info objectForKey: @"event"];
  NSArray *files = [info objectForKey: @"files"];
  NSString *ndpath = [node path];
  int i;

  if ([event isEqual: @"GWFileDeletedInWatchedDirectory"]) {
    for (i = 0; i < [files count]; i++) {  
      NSString *fname = [files objectAtIndex: i];
      NSString *fpath = [ndpath stringByAppendingPathComponent: fname];  
      [self removeRepOfSubnodePath: fpath];
    }
    
  } else if ([event isEqual: @"GWFileCreatedInWatchedDirectory"]) {
    for (i = 0; i < [files count]; i++) {  
      NSString *fname = [files objectAtIndex: i];
      FSNode *subnode = [FSNode nodeWithRelativePath: fname parent: node];
      FSNIcon *icon = [self repOfSubnode: subnode];
      
      if (icon) {
        [icon setNode: subnode];
      } else {
        [self addRepForSubnode: subnode];
      }
    }
  }
  
  [self tile];
  [self setNeedsDisplay: YES];  
  [self selectionDidChange];
}

- (void)setShowType:(FSNInfoType)type
{
  if (infoType != type) {
    int i;
    
    infoType = type;
    DESTROY (extInfoType);
    
    for (i = 0; i < [icons count]; i++) {
      FSNIcon *icon = [icons objectAtIndex: i];
      
      [icon setNodeInfoShowType: infoType];
      [icon tile];
    }
    
    [self sortIcons];
    [self updateNameEditor];
    [self tile];
  }
}

- (void)setExtendedShowType:(NSString *)type
{
  if ((extInfoType == nil) || ([extInfoType isEqual: type] == NO)) {
    int i;
    
    infoType = FSNInfoExtendedType;
    ASSIGN (extInfoType, type);

    for (i = 0; i < [icons count]; i++) {
      FSNIcon *icon = [icons objectAtIndex: i];
      
      [icon setExtendedShowType: extInfoType];
      [icon tile];
    }
    
    [self sortIcons];
    [self updateNameEditor];
    [self tile];
  }
}

- (FSNInfoType)showType
{
  return infoType;
}

- (void)setIconSize:(int)size
{
  int i;
  
  iconSize = size;
  [self calculateGridSize];
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    [icon setIconSize: iconSize];
  }
  
  [self tile];
}

- (int)iconSize
{
  return iconSize;
}

- (void)setLabelTextSize:(int)size
{
  int i;

  labelTextSize = size;
  ASSIGN (labelFont, [NSFont systemFontOfSize: labelTextSize]);  
  [self calculateGridSize];

  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    [icon setFont: labelFont];
  }

  [nameEditor setFont: labelFont];

  [self tile];
}

- (int)labelTextSize
{
  return labelTextSize;
}

- (void)setIconPosition:(int)pos
{
  int i;
  
  iconPosition = pos;
  [self calculateGridSize];
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    [icon setIconPosition: iconPosition];
  }
    
  [self tile];
}

- (int)iconPosition
{
  return iconPosition;
}

- (void)updateIcons
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    FSNode *inode = [icon node];
    [icon setNode: inode];
  }  
}

- (id)repOfSubnode:(FSNode *)anode
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
  
    if ([[icon node] isEqualToNode: anode]) {
      return icon;
    }
  }
  
  return nil;
}

- (id)repOfSubnodePath:(NSString *)apath
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
  
    if ([[[icon node] path] isEqual: apath]) {
      return icon;
    }
  }
  
  return nil;
}

- (id)addRepForSubnode:(FSNode *)anode
{
  FSNIcon *icon = [[FSNIcon alloc] initForNode: anode
                                  nodeInfoType: infoType
                                  extendedType: extInfoType
                                      iconSize: iconSize
                                  iconPosition: iconPosition
                                     labelFont: labelFont
                                     textColor: textColor
                                     gridIndex: -1
                                     dndSource: YES
                                     acceptDnd: YES];
  [icons addObject: icon];
  [self addSubview: icon];
  RELEASE (icon);
  
  return icon;
}

- (id)addRepForSubnodePath:(NSString *)apath
{
  FSNode *subnode = [FSNode nodeWithRelativePath: apath parent: node];
  return [self addRepForSubnode: subnode];
}

- (void)removeRepOfSubnode:(FSNode *)anode
{
  FSNIcon *icon = [self repOfSubnode: anode];

  if (icon) {
    [self removeRep: icon];
  } 
}

- (void)removeRepOfSubnodePath:(NSString *)apath
{
  FSNIcon *icon = [self repOfSubnodePath: apath];

  if (icon) {
    [self removeRep: icon];
  }
}

- (void)removeRep:(id)arep
{
  if (arep == editIcon) {
    editIcon = nil;
  }
  [arep removeFromSuperview];
  [icons removeObject: arep];
}

- (void)unloadFromNode:(FSNode *)anode
{
  FSNode *parent = [FSNode nodeWithRelativePath: [anode parentPath]
                                         parent: nil];
  [self showContentsOfNode: parent];
}

- (void)repSelected:(id)arep
{
}

- (void)unselectOtherReps:(id)arep
{
  int i;

  if (selectionMask & FSNMultipleSelectionMask) {
    return;
  }
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];

    if (icon != arep) {
      [icon unselect];
    }
  }
}

- (void)selectReps:(NSArray *)reps
{
  int i;
  
  selectionMask = NSSingleSelectionMask;
  selectionMask |= FSNCreatingSelectionMask;
  
	[self unselectOtherReps: nil];
  
  selectionMask = FSNMultipleSelectionMask;
  selectionMask |= FSNCreatingSelectionMask;

  for (i = 0; i < [reps count]; i++) {
    [[reps objectAtIndex: i] select];
  }  

  selectionMask = NSSingleSelectionMask;

  [self selectionDidChange];
}

- (void)selectRepsOfSubnodes:(NSArray *)nodes
{
  int i;
  
  selectionMask = NSSingleSelectionMask;
  selectionMask |= FSNCreatingSelectionMask;
  
	[self unselectOtherReps: nil];
  
  selectionMask = FSNMultipleSelectionMask;
  selectionMask |= FSNCreatingSelectionMask;

  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
      
    if ([nodes containsObject: [icon node]]) {  
      [icon select];
    } 
  }  

  selectionMask = NSSingleSelectionMask;

  [self selectionDidChange];
}

- (void)selectRepsOfPaths:(NSArray *)paths
{
  int i;
  
  selectionMask = NSSingleSelectionMask;
  selectionMask |= FSNCreatingSelectionMask;
  
	[self unselectOtherReps: nil];
  
  selectionMask = FSNMultipleSelectionMask;
  selectionMask |= FSNCreatingSelectionMask;

  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
      
    if ([paths containsObject: [[icon node] path]]) {  
      [icon select];
    } 
  }  

  selectionMask = NSSingleSelectionMask;

  [self selectionDidChange];
}

- (void)selectAll
{
	int i;

  selectionMask = NSSingleSelectionMask;
  selectionMask |= FSNCreatingSelectionMask;
  
	[self unselectOtherReps: nil];
  
  selectionMask = FSNMultipleSelectionMask;
  selectionMask |= FSNCreatingSelectionMask;
  
	for (i = 0; i < [icons count]; i++) {
    [[icons objectAtIndex: i] select];
	}
  
  selectionMask = NSSingleSelectionMask;

  [self selectionDidChange];
}

- (NSArray *)reps
{
  return icons;
}

- (NSArray *)selectedReps
{
  NSMutableArray *selectedReps = [NSMutableArray array];
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];

    if ([icon isSelected]) {
      [selectedReps addObject: icon];
    }
  }

  return [NSArray arrayWithArray: selectedReps];
}

- (NSArray *)selectedNodes
{
  NSMutableArray *selectedNodes = [NSMutableArray array];
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];

    if ([icon isSelected]) {
      [selectedNodes addObject: [icon node]];
    }
  }

  return [NSArray arrayWithArray: selectedNodes];
}

- (NSArray *)selectedPaths
{
  NSMutableArray *selectedPaths = [NSMutableArray array];
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];

    if ([icon isSelected]) {
      [selectedPaths addObject: [[icon node] path]];
    }
  }

  return [NSArray arrayWithArray: selectedPaths];
}

- (void)selectionDidChange
{
	if (!(selectionMask & FSNCreatingSelectionMask)) {
    NSArray *selection = [self selectedPaths];
		
    if ([selection count] == 0) {
      selection = [NSArray arrayWithObject: [node path]];
    }

    if ((lastSelection == nil) || ([selection isEqual: lastSelection] == NO)) {
      ASSIGN (lastSelection, selection);
      [desktopApp selectionChanged: selection];
    }
    
    [self updateNameEditor];
	}
}

- (void)checkLockedReps
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    [[icons objectAtIndex: i] checkLocked];
  }
}

- (void)setSelectionMask:(FSNSelectionMask)mask
{
  selectionMask = mask;  
}

- (FSNSelectionMask)selectionMask
{
  return selectionMask;
}

- (void)openSelectionInNewViewer:(BOOL)newv
{
  [desktopApp openSelectionInNewViewer: newv];
}

- (void)restoreLastSelection
{
  if (lastSelection) {
    [self selectRepsOfPaths: lastSelection];
  }
}

- (void)setLastShownNode:(FSNode *)anode
{
}

- (BOOL)involvedByFileOperation:(NSDictionary *)opinfo
{
  return [node involvedByFileOperation: opinfo];
}

- (BOOL)validatePasteOfFilenames:(NSArray *)names
                       wasCutted:(BOOL)cutted
{
  NSString *nodePath = [node path];
  NSString *prePath = [NSString stringWithString: nodePath];
  NSString *basePath;
  
	if ([names count] == 0) {
		return NO;
  } 

  if ([node isWritable] == NO) {
    return NO;
  }
    
  basePath = [[names objectAtIndex: 0] stringByDeletingLastPathComponent];
  if ([basePath isEqual: nodePath]) {
    return NO;
  }  
    
  if ([names containsObject: nodePath]) {
    return NO;
  }

  while (1) {
    if ([names containsObject: prePath]) {
      return NO;
    }
    if ([prePath isEqual: path_separator()]) {
      break;
    }            
    prePath = [prePath stringByDeletingLastPathComponent];
  }

  return YES;
}

- (void)setBackgroundColor:(NSColor *)acolor
{
  ASSIGN (backColor, acolor);
  [[self window] setBackgroundColor: backColor];
  [self setNeedsDisplay: YES];
}
                       
- (NSColor *)backgroundColor
{
  return backColor;
}

- (void)setTextColor:(NSColor *)acolor
{
  int i;
  
	for (i = 0; i < [icons count]; i++) {
    [[icons objectAtIndex: i] setLabelTextColor: acolor];  
  }
  
  [nameEditor setTextColor: acolor];
  
  ASSIGN (textColor, acolor);
}

- (NSColor *)textColor
{
  return textColor;
}

- (NSColor *)disabledTextColor
{
  return disabledTextColor;
}

@end


@implementation FSNIconsView (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb;
  NSDragOperation sourceDragMask;
	NSArray *sourcePaths;
  NSString *basePath;
  NSString *nodePath;
  NSString *prePath;
	int count;
  
	isDragTarget = NO;	
    
 	pb = [sender draggingPasteboard];

  if (pb && [[pb types] containsObject: NSFilenamesPboardType]) {
    sourcePaths = [pb propertyListForType: NSFilenamesPboardType]; 
       
  } else if ([[pb types] containsObject: @"GWRemoteFilenamesPboardType"]) {
    NSData *pbData = [pb dataForType: @"GWRemoteFilenamesPboardType"]; 
    NSDictionary *pbDict = [NSUnarchiver unarchiveObjectWithData: pbData];
    
    sourcePaths = [pbDict objectForKey: @"paths"];
  } else {
    return NSDragOperationNone;
  }

	count = [sourcePaths count];
	if (count == 0) {
		return NSDragOperationNone;
  } 
    
  if ([node isWritable] == NO) {
    return NSDragOperationNone;
  }
    
  nodePath = [node path];

  basePath = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];
  if ([basePath isEqual: nodePath]) {
    return NSDragOperationNone;
  }
  
  if ([sourcePaths containsObject: nodePath]) {
    return NSDragOperationNone;
  }

  prePath = [NSString stringWithString: nodePath];

  while (1) {
    if ([sourcePaths containsObject: prePath]) {
      return NSDragOperationNone;
    }
    if ([prePath isEqual: path_separator()]) {
      break;
    }            
    prePath = [prePath stringByDeletingLastPathComponent];
  }

  isDragTarget = YES;	
    
	sourceDragMask = [sender draggingSourceOperationMask];

	if (sourceDragMask == NSDragOperationCopy) {
		return NSDragOperationCopy;
	} else if (sourceDragMask == NSDragOperationLink) {
		return NSDragOperationLink;
	} else {
		return NSDragOperationAll;
	}		

  isDragTarget = NO;	
  return NSDragOperationNone;
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
  NSRect vr = [self visibleRect];
  NSRect scr = vr;
  int xsc = 0.0;
  int ysc = 0.0;
  int sc = 0;
  float margin = 4.0;
  NSRect ir = NSInsetRect(vr, margin, margin);
  NSPoint p = [sender draggingLocation];
  int i;
  
  p = [self convertPoint: p fromView: nil];

  if ([self mouse: p inRect: ir] == NO) {
    if (p.x < (NSMinX(vr) + margin)) {
      xsc = -gridSize.width;
    } else if (p.x > (NSMaxX(vr) - margin)) {
      xsc = gridSize.width;
    }

    if (p.y < (NSMinY(vr) + margin)) {
      ysc = -gridSize.height;
    } else if (p.y > (NSMaxY(vr) - margin)) {
      ysc = gridSize.height;
    }

    sc = (abs(xsc) >= abs(ysc)) ? xsc : ysc;
          
    for (i = 0; i < abs(sc / margin); i++) {
      NSDate *limit = [NSDate dateWithTimeIntervalSinceNow: 0.01];
      int x = (abs(xsc) >= i) ? (xsc > 0 ? margin : -margin) : 0;
      int y = (abs(ysc) >= i) ? (ysc > 0 ? margin : -margin) : 0;
      
      scr = NSOffsetRect(scr, x, y);
      [self scrollRectToVisible: scr];

      vr = [self visibleRect];
      ir = NSInsetRect(vr, margin, margin);

      p = [[self window] mouseLocationOutsideOfEventStream];
      p = [self convertPoint: p fromView: nil];

      if ([self mouse: p inRect: ir]) {
        break;
      }
      
      [[NSRunLoop currentRunLoop] runUntilDate: limit];
    }
  }
  
	if (isDragTarget == NO) {
		return NSDragOperationNone;
	}

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
	isDragTarget = NO;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	return isDragTarget;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
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

	isDragTarget = NO;  

	sourceDragMask = [sender draggingSourceOperationMask];
  pb = [sender draggingPasteboard];
    
  if ([[pb types] containsObject: @"GWRemoteFilenamesPboardType"]) {  
    NSData *pbData = [pb dataForType: @"GWRemoteFilenamesPboardType"]; 

    [desktopApp concludeRemoteFilesDragOperation: pbData
                                     atLocalPath: [node path]];
    return;
  }
    
  sourcePaths = [pb propertyListForType: NSFilenamesPboardType];
  
  if ([sourcePaths count] == 0) {
    return;
  }
  
  source = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];
  
  trashPath = [desktopApp trashPath];

  if ([source isEqual: trashPath]) {
    operation = @"GWorkspaceRecycleOutOperation";
	} else {	
		if (sourceDragMask == NSDragOperationCopy) {
			operation = NSWorkspaceCopyOperation;
		} else if (sourceDragMask == NSDragOperationLink) {
			operation = NSWorkspaceLinkOperation;
		} else {
			operation = NSWorkspaceMoveOperation;
		}
  }

  files = [NSMutableArray array];    
  for(i = 0; i < [sourcePaths count]; i++) {    
    [files addObject: [[sourcePaths objectAtIndex: i] lastPathComponent]];
  }  

	opDict = [NSMutableDictionary dictionary];
	[opDict setObject: operation forKey: @"operation"];
	[opDict setObject: source forKey: @"source"];
	[opDict setObject: [node path] forKey: @"destination"];
	[opDict setObject: files forKey: @"files"];

  [desktopApp performFileOperation: opDict];
}

@end


@implementation FSNIconsView (IconNameEditing)

- (void)updateNameEditor
{
  NSArray *selection = [self selectedNodes];
  NSRect edrect;

  if ([[self subviews] containsObject: nameEditor]) {
    edrect = [nameEditor frame];
    [nameEditor abortEditing];
    [nameEditor setNode: nil stringValue: @"" index: -1];
    [nameEditor removeFromSuperview];
    [self setNeedsDisplayInRect: edrect];
  }

  if (editIcon) {
    [editIcon setNameEdited: NO];
  }

  editIcon = nil;
  
  if ([selection count] == 1) {
    editIcon = [self repOfSubnode: [selection objectAtIndex: 0]]; 
  } 
  
  if (editIcon) {
    FSNode *iconnode = [editIcon node];
    NSString *nodeDescr = [editIcon shownInfo];
    BOOL locked = [editIcon isLocked];
    BOOL mpoint = [iconnode isMountPoint];
    NSRect icnr = [editIcon frame];
    NSRect labr = [editIcon labelRect];
    int ipos = [editIcon iconPosition];
    int margin = [FSNodeRep labelMargin];
    float bw = [self bounds].size.width - EDIT_MARGIN;
    float edwidth = 0.0; 
    NSFontManager *fmanager = [NSFontManager sharedFontManager];
    NSFont *edfont = [nameEditor font];
    
    [editIcon setNameEdited: YES];
  
    if ([editIcon nodeInfoShowType] == FSNInfoExtendedType) {
      edfont = [fmanager convertFont: edfont 
                         toHaveTrait: NSItalicFontMask];
    } else {
      edfont = [fmanager convertFont: edfont 
                      toNotHaveTrait: NSItalicFontMask];
    }
    
    [nameEditor setFont: edfont];
    
    edwidth = [[nameEditor font] widthOfString: nodeDescr];
    edwidth += margin;
    
    if (ipos == NSImageAbove) {
      float centerx = icnr.origin.x + (icnr.size.width / 2);

      if ((centerx + (edwidth / 2)) >= bw) {
        centerx -= (centerx + (edwidth / 2) - bw);
      } else if ((centerx - (edwidth / 2)) < margin) {
        centerx += fabs(centerx - (edwidth / 2)) + margin;
      }    
 
      edrect = [self convertRect: labr fromView: editIcon];
      edrect.origin.x = centerx - (edwidth / 2);
      edrect.size.width = edwidth;
      
    } else if (ipos == NSImageLeft) {
      edrect = [self convertRect: labr fromView: editIcon];
      edrect.size.width = edwidth;
    
      if ((edrect.origin.x + edwidth) >= bw) {
        edrect.size.width = bw - edrect.origin.x;
      }    
    }
    
    edrect = NSIntegralRect(edrect);
    
    [nameEditor setFrame: edrect];
    
    if (ipos == NSImageAbove) {
		  [nameEditor setAlignment: NSCenterTextAlignment];
    } else if (ipos == NSImageLeft) {
		  [nameEditor setAlignment: NSLeftTextAlignment];
    }
        
    [nameEditor setNode: iconnode 
            stringValue: nodeDescr
                  index: 0];

    [nameEditor setBackgroundColor: [NSColor selectedControlColor]];
    
    if (locked == NO) {
      [nameEditor setTextColor: textColor];    
    } else {
      [nameEditor setTextColor: [self disabledTextColor]];    
    }

    [nameEditor setEditable: ((locked == NO) && (mpoint == NO) && (infoType == FSNInfoNameType))];
    [nameEditor setSelectable: ((locked == NO) && (mpoint == NO) && (infoType == FSNInfoNameType))];	
    [self addSubview: nameEditor];
  }
}

- (void)stopRepNameEditing
{
  if ([[self subviews] containsObject: nameEditor]) {
    NSRect edrect = [nameEditor frame];
    [nameEditor abortEditing];
    [nameEditor setNode: nil stringValue: @"" index: -1];
    [nameEditor removeFromSuperview];
    [self setNeedsDisplayInRect: edrect];
  }

  if (editIcon) {
    [editIcon setNameEdited: NO];
  }

  editIcon = nil;
}

- (void)unselectNameEditor
{
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  NSRect icnr = [editIcon frame];
  int ipos = [editIcon iconPosition];
  float edwidth = [[nameEditor font] widthOfString: [nameEditor stringValue]]; 
  int margin = [FSNodeRep labelMargin];
  float bw = [self bounds].size.width - EDIT_MARGIN;
  NSRect edrect = [nameEditor frame];
  
  edwidth += margin;

  if (ipos == NSImageAbove) {
    float centerx = icnr.origin.x + (icnr.size.width / 2);

    while ((centerx + (edwidth / 2)) > bw) {
      centerx --;  
      if (centerx < EDIT_MARGIN) {
        break;
      }
    }

    while ((centerx - (edwidth / 2)) < EDIT_MARGIN) {
      centerx ++;  
      if (centerx >= bw) {
        break;
      }
    }
        
    edrect.origin.x = centerx - (edwidth / 2);
    edrect.size.width = edwidth;
    
  } else if (ipos == NSImageLeft) {
    edrect.size.width = edwidth;

    if ((edrect.origin.x + edwidth) >= bw) {
      edrect.size.width = bw - edrect.origin.x;
    }    
  }
  
  [self setNeedsDisplayInRect: [nameEditor frame]];
  [nameEditor setFrame: NSIntegralRect(edrect)];
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
  FSNode *ednode = [nameEditor node];

#define CLEAREDITING \
  [self stopRepNameEditing]; \
  return 
 
  if ([ednode isWritable] == NO) {
    NSRunAlertPanel(NSLocalizedString(@"Error", @""), 
          [NSString stringWithFormat: @"%@\"%@\"!\n", 
              NSLocalizedString(@"You have not write permission for ", @""), 
                    [ednode name]], NSLocalizedString(@"Continue", @""), nil, nil);   
    CLEAREDITING;
    
  } else if ([[ednode parent] isWritable] == NO) {
    NSRunAlertPanel(NSLocalizedString(@"Error", @""), 
          [NSString stringWithFormat: @"%@\"%@\"!\n", 
              NSLocalizedString(@"You have not write permission for ", @""), 
                  [[ednode parent] name]], NSLocalizedString(@"Continue", @""), nil, nil);   
    CLEAREDITING;
    
  } else {
    NSString *newname = [nameEditor stringValue];
    NSString *newpath = [[ednode parentPath] stringByAppendingPathComponent: newname];
    NSCharacterSet *notAllowSet = [NSCharacterSet characterSetWithCharactersInString: @"/\\*$|~\'\"`^!?"];
    NSRange range = [newname rangeOfCharacterFromSet: notAllowSet];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *dirContents = [fm directoryContentsAtPath: [ednode parentPath]];
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    
    if (range.length > 0) {
      NSRunAlertPanel(NSLocalizedString(@"Error", @""), 
                NSLocalizedString(@"Invalid char in name", @""), 
                          NSLocalizedString(@"Continue", @""), nil, nil);   
      CLEAREDITING;
    }	

    if ([dirContents containsObject: newname]) {
      if ([newname isEqual: [ednode name]]) {
        CLEAREDITING;
      } else {
        NSRunAlertPanel(NSLocalizedString(@"Error", @""), 
          [NSString stringWithFormat: @"%@\"%@\" %@ ", 
              NSLocalizedString(@"The name ", @""), 
              newname, NSLocalizedString(@" is already in use!", @"")], 
                            NSLocalizedString(@"Continue", @""), nil, nil);   
        CLEAREDITING;
      }
    }

	  [userInfo setObject: @"GWorkspaceRenameOperation" forKey: @"operation"];	
    [userInfo setObject: [ednode path] forKey: @"source"];	
    [userInfo setObject: newpath forKey: @"destination"];	
    [userInfo setObject: [NSArray arrayWithObject: @""] forKey: @"files"];	
    
    [desktopApp removeWatcherForPath: [node path]];
  
    [[NSDistributedNotificationCenter defaultCenter]
 				postNotificationName: @"GWFileSystemWillChangeNotification"
	 								    object: nil 
                    userInfo: userInfo];

    [fm movePath: [ednode path] toPath: newpath handler: self];

    [[NSDistributedNotificationCenter defaultCenter]
 				postNotificationName: @"GWFileSystemDidChangeNotification"
	 								    object: nil 
                    userInfo: userInfo];
    
    [desktopApp addWatcherForPath: [node path]];
  }
}

- (BOOL)fileManager:(NSFileManager *)manager 
              shouldProceedAfterError:(NSDictionary *)errorDict
{
	NSString *title = NSLocalizedString(@"Error", @"");
	NSString *msg1 = NSLocalizedString(@"Cannot rename ", @"");
  NSString *name = [[nameEditor node] name];
	NSString *msg2 = NSLocalizedString(@"Continue", @"");

  NSRunAlertPanel(title, [NSString stringWithFormat: @"%@'%@'!", msg1, name], msg2, nil, nil);   

	return NO;
}

- (void)fileManager:(NSFileManager *)manager willProcessPath:(NSString *)path
{
}

@end






















