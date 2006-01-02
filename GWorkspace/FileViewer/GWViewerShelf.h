/* GWViewerShelf.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: July 2004
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

#ifndef GWVIEWER_SHELF_H
#define GWVIEWER_SHELF_H

#include <Foundation/Foundation.h>
#include <AppKit/NSView.h>
#include "FSNodeRep.h"

@class GWorkspace;

@interface GWViewerShelf : NSView
{
	NSMutableArray *icons; 

  int iconSize;
  int labelTextSize;
  NSFont *labelFont;
  int iconPosition;

  FSNInfoType infoType;
  NSString *extInfoType;

  NSRect *grid;
  NSSize gridSize;  
  int gridcount;
  int colcount;
  int rowcount;
  
  NSCountedSet *watchedPaths;
  
  NSImage *dragIcon;
  NSPoint dragPoint;
  int insertIndex;
	BOOL dragLocalIcon;
  BOOL isDragTarget;

  NSColor *backColor;
  NSColor *textColor;
  NSColor *disabledTextColor;

  FSNodeRep *fsnodeRep;

  id viewer;
  GWorkspace *gworkspace;
}

- (id)initWithFrame:(NSRect)frameRect
          forViewer:(id)vwr;

- (void)setContents:(NSArray *)iconsInfo;

- (NSArray *)contentsInfo;

- (id)addIconForNode:(FSNode *)node
             atIndex:(int)index;

- (id)addIconForSelection:(NSArray *)selection
                  atIndex:(int)index;

- (id)iconForNode:(FSNode *)node;

- (id)iconForPath:(NSString *)path;

- (id)iconForNodesSelection:(NSArray *)selection;

- (id)iconForPathsSelection:(NSArray *)selection;

- (void)calculateGridSize;

- (void)makeIconsGrid;

- (int)firstFreeGridIndex;

- (int)firstFreeGridIndexAfterIndex:(int)index;

- (BOOL)isFreeGridIndex:(int)index;

- (id)iconWithGridIndex:(int)index;

- (int)indexOfGridRectContainingPoint:(NSPoint)p;

- (NSRect)iconBoundsInGridAtIndex:(int)index;

- (void)tile;

- (void)setWatcherForPath:(NSString *)path;

- (void)unsetWatcherForPath:(NSString *)path;

- (void)unsetWatchers;

- (NSArray *)watchedPaths;

- (void)checkIconsAfterDotsFilesChange;

- (void)checkIconsAfterHidingOfPaths:(NSArray *)hpaths;

@end


@interface GWViewerShelf (NodeRepContainer)

- (void)removeRep:(id)arep;
- (void)removeUndepositedRep:(id)arep;

- (void)repSelected:(id)arep;
- (void)unselectOtherReps:(id)arep;
- (NSArray *)selectedPaths;  

- (void)nodeContentsWillChange:(NSDictionary *)info;
- (void)nodeContentsDidChange:(NSDictionary *)info;
- (void)watchedPathChanged:(NSDictionary *)info;

- (void)checkLockedReps;
- (FSNSelectionMask)selectionMask;
- (void)restoreLastSelection;

- (NSColor *)backgroundColor;
- (NSColor *)textColor;
- (NSColor *)disabledTextColor;

@end


@interface GWViewerShelf (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender;

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender;

- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

@end

#endif // GWVIEWER_SHELF_H

