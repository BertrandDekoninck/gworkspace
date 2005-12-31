/* FModuleSize.m
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
#include <limits.h>
#include "FinderModulesProtocol.h"

static NSString *nibName = @"FModuleSize";

@interface FModuleSize : NSObject <FinderModulesProtocol>
{  
  IBOutlet id win;
  IBOutlet id controlsBox;
  IBOutlet id popUp;
  IBOutlet id textField;
  int index;
  BOOL used;

  NSFileManager *fm;
  unsigned long long size;
  int how;
}

- (IBAction)popUpAction:(id)sender; 

@end

@implementation FModuleSize

#define GREATER 0
#define LESS    1

- (void)dealloc
{
  TEST_RELEASE (controlsBox);
  [super dealloc];
}

- (id)initInterface
{
	self = [super init];

  if (self) {
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      DESTROY (self);
      return self;
    }

    RETAIN (controlsBox);
    RELEASE (win);

    used = NO;
    index = 0;
    
    [textField setStringValue: @""];

    /* Internationalization */    
    [popUp removeAllItems];
    [popUp insertItemWithTitle: NSLocalizedString(@"greater then", @"") atIndex: 0];
    [popUp insertItemWithTitle: NSLocalizedString(@"less then", @"") atIndex: 1];
    [popUp selectItemAtIndex: 0]; 
  }
  
	return self;
}

- (id)initWithSearchCriteria:(NSDictionary *)criteria
                  searchTool:(id)tool
{
	self = [super init];

  if (self) {
    size = [[criteria objectForKey: @"what"] unsignedLongLongValue];
    how = [[criteria objectForKey: @"how"] intValue];
    fm = [NSFileManager defaultManager];
  }
  
	return self;
}

- (IBAction)popUpAction:(id)sender
{
}

- (void)setControlsState:(NSDictionary *)info
{
  NSNumber *idxnum = [info objectForKey: @"how"];
  NSNumber *sizenum = [info objectForKey: @"what"];

  if (idxnum) {
    [popUp selectItemAtIndex: [idxnum intValue]];
  }

  if (sizenum) {
    [textField setStringValue: [sizenum stringValue]];
  }    
}

- (id)controls
{
  return controlsBox;
}

- (NSString *)moduleName
{
  return NSLocalizedString(@"size", @"");
}

- (BOOL)used
{
  return used;
}

- (void)setInUse:(BOOL)value
{
  used = value;
}

- (int)index
{
  return index;
}

- (void)setIndex:(int)idx
{
  index = idx;
}

- (NSDictionary *)searchCriteria
{
  NSString *str = [textField stringValue];
  
  if ([str length] != 0) {
    int sz = [str intValue];
  
    if ((sz > 0) && (sz < INT_MAX)) {
      NSMutableDictionary *criteria = [NSMutableDictionary dictionary];
      int idx = [popUp indexOfSelectedItem];
  
      [criteria setObject: [NSNumber numberWithLong: sz] forKey: @"what"];  
      [criteria setObject: [NSNumber numberWithInt: idx] forKey: @"how"];
  
      return criteria;
    }
  }

  return nil;
}

- (BOOL)checkPath:(NSString *)path 
   withAttributes:(NSDictionary *)attributes
{
  unsigned long long fs = ([attributes fileSize] >> 10);

  if (fs < size) {
    return (how == LESS) ? YES : NO;    
  } else if (fs > size) {
    return (how == GREATER) ? YES : NO;    
  } 

  return NO;
}

- (int)compareModule:(id <FinderModulesProtocol>)module
{
  int i1 = [self index];
  int i2 = [module index];

  if (i1 < i2) {
    return NSOrderedAscending;
  } else if (i1 > i2) {
    return NSOrderedDescending;
  } 

  return NSOrderedSame;
}

- (BOOL)reliesOnModDate
{
  return NO;
}

- (BOOL)metadataModule
{
  return NO;
}

@end










