/* externs.h
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
 *
 * This file is part of the GNUstep gwsd tool
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

#ifndef EXTERNS_H
#define EXTERNS_H

/* Class variables */
extern NSMutableDictionary *cachedContents;
extern int cachedMax;

extern NSMutableArray *lockedPaths;

extern NSRecursiveLock *gwsdLock;

/* File Operations */
extern NSString *NSWorkspaceMoveOperation;
extern NSString *NSWorkspaceCopyOperation;
extern NSString *NSWorkspaceLinkOperation;
extern NSString *NSWorkspaceDestroyOperation;
extern NSString *NSWorkspaceDuplicateOperation;
extern NSString *NSWorkspaceRecycleOperation;
extern NSString *GWorkspaceRecycleOutOperation;
extern NSString *GWorkspaceEmptyRecyclerOperation;

/* Notifications */
extern NSString *GWFileSystemWillChangeNotification;
extern NSString *GWFileSystemDidChangeNotification; 

extern NSString *GWFileWatcherFileDidChangeNotification; 
extern NSString *GWWatchedDirectoryDeleted; 
extern NSString *GWFileDeletedInWatchedDirectory; 
extern NSString *GWFileCreatedInWatchedDirectory;

#endif // EXTERNS_H
