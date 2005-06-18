/* Notifications.h
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
 *
 * This file is part of the GNUstep GWRemote application
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

#ifndef NOTIFICATIONS_H
#define NOTIFICATIONS_H

/* Notifications */
extern NSString *GWFileSystemWillChangeNotification;
extern NSString *GWFileSystemDidChangeNotification;
extern NSString *GWSortTypeDidChangeNotification;

/* Geometry Notifications */
extern NSString *GWBrowserColumnWidthChangedNotification;
extern NSString *GWShelfCellsWidthChangedNotification;

/* File Watcher Notifications */
extern NSString *GWFileWatcherFileDidChangeNotification;
extern NSString *GWWatchedDirectoryDeleted;
extern NSString *GWFileDeletedInWatchedDirectory;
extern NSString *GWFileCreatedInWatchedDirectory;

/* File Operations */
extern NSString *GWorkspaceCreateFileOperation;
extern NSString *GWorkspaceCreateDirOperation;
extern NSString *GWorkspaceRenameOperation;
extern NSString *GWorkspaceRecycleOutOperation;    
extern NSString *GWorkspaceEmptyRecyclerOperation;

extern NSString *GWRemoteFilenamesPboardType;

#endif // NOTIFICATIONS_H
