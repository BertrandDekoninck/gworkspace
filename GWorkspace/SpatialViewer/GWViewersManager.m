/* GWViewersManager.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: June 2004
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

#include <AppKit/AppKit.h>
#include "GWViewersManager.h"
#include "GWSpatialViewer.h"
#include "FSNodeRep.h"
#include "FSNIcon.h"
#include "FSNFunctions.h"
#include "GWorkspace.h"

static GWViewersManager *vwrsmanager = nil;

@implementation GWViewersManager

+ (GWViewersManager *)viewersManager
{
	if (vwrsmanager == nil) {
		vwrsmanager = [[GWViewersManager alloc] init];
	}	
  return vwrsmanager;
}

- (void)dealloc
{
  RELEASE (viewers);
    
	[super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
    viewers = [NSMutableArray new];
    gworkspace = [GWorkspace gworkspace];
    [FSNodeRep setLabelWFactor: 9.0];
    [FSNodeRep setUseThumbnails: YES];
  }
  
  return self;
}

- (id)newViewerForPath:(NSString *)path
        closeOldViewer:(GWSpatialViewer *)oldvwr
{
  GWSpatialViewer *viewer = [self viewerForPath: path];
  NSArray *icons;
  int i;
  
  if (viewer == nil) {
    FSNode *node = [FSNode nodeWithRelativePath: path parent: nil];
  
    viewer = [[GWSpatialViewer alloc] initForNode: node];    
    [viewers addObject: viewer];
    RELEASE (viewer);
  } 

  if (oldvwr) {  
    [[oldvwr win] close]; 
  }
  
  [viewer activate];
      
  icons = [viewer icons];  
    
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];  
    
    if ([self viewerForPath: [[icon node] path]]) {
      [icon setOpened: YES];
    }
  }
     
  return viewer;
}

- (id)viewerForPath:(NSString *)path
{
  int i;
  
  for (i = 0; i < [viewers count]; i++) {
    GWSpatialViewer *viewer = [viewers objectAtIndex: i];
    FSNode *node = [viewer shownNode];
    
    if ([[node path] isEqual: path]) {
      return viewer;
    }
  }
  
  return nil;
}

- (void)viewerSelected:(GWSpatialViewer *)aviewer
{
  GWSpatialViewer *parentViewer = [self parentOfViewer: aviewer];
  
  [self unselectOtherViewers: aviewer];
  
  if (parentViewer) {
    [parentViewer setOpened: YES iconOfPath: [[aviewer shownNode] path]];
  }
}

- (void)unselectOtherViewers:(GWSpatialViewer *)aviewer
{
  int i;
  
  for (i = 0; i < [viewers count]; i++) {
    GWSpatialViewer *viewer = [viewers objectAtIndex: i];

    if (viewer != aviewer) {
      [viewer unselectAllIcons];
    }
  }  
}

- (void)selectionDidChangeInViewer:(GWSpatialViewer *)aviewer
{
  GWSpatialViewer *parentViewer = [self parentOfViewer: aviewer];

  if (parentViewer) {
    [parentViewer unselectAllIcons]; 
  }
}

- (void)viewerWillClose:(GWSpatialViewer *)aviewer
{
  GWSpatialViewer *parentViewer = [self parentOfViewer: aviewer];

  if (parentViewer) {
    [parentViewer setOpened: NO iconOfPath: [[aviewer shownNode] path]];
  }
    
  [viewers removeObject: aviewer];
}

- (GWSpatialViewer *)parentOfViewer:(GWSpatialViewer *)aviewer
{
  FSNode *node = [aviewer shownNode];

  if ([[node path] isEqual: path_separator()] == NO) {
    return [self viewerForPath: [node parentPath]];
  }
    
  return nil;  
}

- (void)selectionChanged:(NSArray *)selection
{
  [gworkspace selectionChanged: selection];
}

- (void)openSelectionInViewer:(GWSpatialViewer *)viewer
                  closeSender:(BOOL)close
{
  NSArray *selnodes = [viewer selectedNodes];
  int i;
  
  for (i = 0; i < [selnodes count]; i++) {
    FSNode *node = [selnodes objectAtIndex: i];
    NSString *path = [node path];
        
    if ([node isDirectory]) {
      [self newViewerForPath: path closeOldViewer: (close ? viewer : nil)]; 
    } else if ([node isPlain]) {
      [gworkspace openFile: path];
    } else if ([node isApplication]) {
      [[NSWorkspace sharedWorkspace] launchApplication: path];
    }
  }
}

@end









