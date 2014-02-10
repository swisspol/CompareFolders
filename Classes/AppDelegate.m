//  This file is part of the Compare Folders application for iOS.
//  Copyright (C) 2014 Pierre-Olivier Latour <info@pol-online.net>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.

#import "AppDelegate.h"

static NSColor* _rowColors[6];

@implementation TableView

- (void)drawRow:(NSInteger)index clipRect:(NSRect)clipRect {
  if (![self isRowSelected:index]) {
    NSArrayController* controller = [(AppDelegate*)[NSApp delegate] arrayController];
    Row* row = [controller.arrangedObjects objectAtIndex:index];
    ComparisonResult result = row.result;
    NSColor* color;
    if (result & (kComparisonResult_Removed | kComparisonResult_Added | kComparisonResult_Replaced)) {
      color = index % 2 ? _rowColors[2] : _rowColors[3];
    } else if (result & kComparisonResult_ModifiedMask) {
      if (!row.leftItem.isDirectory && (result & (kComparisonResult_Modified_FileDataContent | kComparisonResult_Modified_FileResourceContent | kComparisonResult_Modified_FileDataSize | kComparisonResult_Modified_FileResourceSize | kComparisonResult_Modified_ModificationDate))) {
        color = index % 2 ? _rowColors[2] : _rowColors[3];
      } else {
        color = index % 2 ? _rowColors[0] : _rowColors[1];
      }
    } else {
      color = index % 2 ? _rowColors[4] : _rowColors[5];
    }
    [color setFill];
    NSRectFill([self rectOfRow:index]);
  }
  [super drawRow:index clipRect:clipRect];
}

@end

@implementation Row

- (BOOL)differentPermissions {
  return _result & kComparisonResult_Modified_Permissions ? YES : NO;
}

- (BOOL)differentGroupID {
  return _result & kComparisonResult_Modified_GroupID ? YES : NO;
}

- (BOOL)differentUserID {
  return _result & kComparisonResult_Modified_UserID ? YES : NO;
}

- (BOOL)differentCreationDates {
  return _result & kComparisonResult_Modified_CreationDate ? YES : NO;
}

- (BOOL)differentModificationsDates {
  return _result & kComparisonResult_Modified_ModificationDate ? YES : NO;
}

- (BOOL)differentFileDataSizes {
  return _result & kComparisonResult_Modified_FileDataSize ? YES : NO;
}

- (BOOL)differentFileResourceSizes {
  return _result & kComparisonResult_Modified_FileResourceSize ? YES : NO;
}

@end

@implementation AppDelegate

+ (void)initialize {
  NSDictionary* defaults = @{
                             kUserDefaultKey_ChecksumFiles: @NO,
                             kUserDefaultKey_FilterIdentical: @NO,
                             kUserDefaultKey_FilterHidden: @NO,
                             kUserDefaultKey_FilterFiles: @NO,
                             kUserDefaultKey_FilterFolders: @NO,
                             kUserDefaultKey_FilterLinks: @NO,
                             kUserDefaultKey_FilterPermissions: @NO,
                             kUserDefaultKey_FilterCreations: @NO,
                             kUserDefaultKey_FilterModifications: @NO
                             };
  [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
  
  _rowColors[0] = [NSColor colorWithDeviceHue:0.1 saturation:0.2 brightness:1.0 alpha:1.0];  // Light orange
  _rowColors[1] = [NSColor colorWithDeviceHue:0.1 saturation:0.3 brightness:1.0 alpha:1.0];  // Dark orange
  _rowColors[2] = [NSColor colorWithDeviceHue:1.0 saturation:0.2 brightness:1.0 alpha:1.0];  // Light red
  _rowColors[3] = [NSColor colorWithDeviceHue:1.0 saturation:0.3 brightness:1.0 alpha:1.0];  // Dark red
  _rowColors[4] = [NSColor colorWithDeviceHue:0.3 saturation:0.2 brightness:1.0 alpha:1.0];  // Light green
  _rowColors[5] = [NSColor colorWithDeviceHue:0.3 saturation:0.3 brightness:1.0 alpha:1.0];  // Dark green
}

- (void)awakeFromNib {
  NSTableHeaderCell* leftCell = [[_tableView tableColumnWithIdentifier:@"leftPath"] headerCell];
  leftCell.lineBreakMode = NSLineBreakByTruncatingMiddle;  // Can't be set in IB?
  NSTableHeaderCell* rightCell = [[_tableView tableColumnWithIdentifier:@"rightPath"] headerCell];
  rightCell.lineBreakMode = NSLineBreakByTruncatingMiddle;  // Can't be set in IB?
}

- (void)_compareFolders:(BOOL)force {
  if (_leftPath) {
    [(NSTableHeaderCell*)[[_tableView tableColumnWithIdentifier:@"leftPath"] headerCell] setStringValue:_leftPath];
    [_tableView.headerView setNeedsDisplay:YES];
  }
  if (_rightPath) {
    [(NSTableHeaderCell*)[[_tableView tableColumnWithIdentifier:@"rightPath"] headerCell] setStringValue:_rightPath];
    [_tableView.headerView setNeedsDisplay:YES];
  }
  if (_leftPath && _rightPath) {
    ComparisonOptions options = 0;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kUserDefaultKey_ChecksumFiles]) {
      options |= kComparisonOption_FileContent;
    }
    if (force) {
      _rows = [[NSMutableArray alloc] init];
      DirectoryItem* leftRoot = [[DirectoryItem alloc] initWithPath:_leftPath];
      DirectoryItem* rightRoot = [[DirectoryItem alloc] initWithPath:_rightPath];
      if (leftRoot && rightRoot) {
        [leftRoot compareDirectory:rightRoot options:options withBlock:^(ComparisonResult result, Item* item, Item* otherItem) {
          Row* row = [[Row alloc] init];
          row.result = result;
          row.leftItem = item;
          row.rightItem = otherItem;
          [_rows addObject:row];
        }];
        self.ready = YES;
      }
    }
    if (_rows) {
      BOOL filterIdentical = [[NSUserDefaults standardUserDefaults] boolForKey:kUserDefaultKey_FilterIdentical];
      BOOL filterHidden = [[NSUserDefaults standardUserDefaults] boolForKey:kUserDefaultKey_FilterHidden];
      BOOL filterFiles = [[NSUserDefaults standardUserDefaults] boolForKey:kUserDefaultKey_FilterFiles];
      BOOL filterFolders = [[NSUserDefaults standardUserDefaults] boolForKey:kUserDefaultKey_FilterFolders];
      BOOL filterLinks = [[NSUserDefaults standardUserDefaults] boolForKey:kUserDefaultKey_FilterLinks];
      BOOL filterPermissions = [[NSUserDefaults standardUserDefaults] boolForKey:kUserDefaultKey_FilterPermissions];
      BOOL filterCreations = [[NSUserDefaults standardUserDefaults] boolForKey:kUserDefaultKey_FilterCreations];
      BOOL filterModifications = [[NSUserDefaults standardUserDefaults] boolForKey:kUserDefaultKey_FilterModifications];
      if (filterHidden || filterIdentical || filterFiles || filterFolders || filterLinks || filterPermissions || filterCreations || filterModifications) {
        NSMutableArray* array = [[NSMutableArray alloc] initWithCapacity:_rows.count];
        for (Row* row in _rows) {
          ComparisonResult result = row.result;
          Item* leftItem = row.leftItem;
          Item* rightItem = row.rightItem;
          if (filterHidden && ([leftItem.name hasPrefix:@"."] || [rightItem.name hasPrefix:@"."])) {
            continue;
          }
          if (filterIdentical && !result) {
            continue;
          }
          if (filterFiles && (leftItem.isFile || rightItem.isFile)) {
            continue;
          }
          if (filterFolders && (leftItem.isDirectory || rightItem.isDirectory)) {
            continue;
          }
          if (filterLinks && (leftItem.isSymLink || rightItem.isSymLink)) {
            continue;
          }
          if (result & kComparisonResult_ModifiedMask) {
            ComparisonResult mask = 0;
            if (filterPermissions) {
              mask |= kComparisonResult_Modified_Permissions | kComparisonResult_Modified_GroupID | kComparisonResult_Modified_UserID;
            }
            if (filterCreations) {
              mask |= kComparisonResult_Modified_CreationDate;
            }
            if (filterModifications && (leftItem.isDirectory || rightItem.isDirectory)) {
              mask |= kComparisonResult_Modified_ModificationDate;
            }
            if (mask && (result & mask) && !(result & ~mask)) {
              continue;
            }
          }
          [array addObject:row];
        }
        [_arrayController setContent:array];
      } else {
        [_arrayController setContent:_rows];
      }
    }
  }
}

#ifndef NDEBUG

- (BOOL)_saveBookmark:(NSString*)defaultKey withURL:(NSURL*)url {
  NSError* error = nil;
  NSData* data = [url bookmarkDataWithOptions:(NSURLBookmarkCreationWithSecurityScope | NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess) includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
  if (data) {
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:defaultKey];
    return YES;
  }
  NSLog(@"Failed saving bookmark: %@", error);
  return NO;
}

- (NSString*)_loadBookmark:(NSString*)defaultKey {
  NSData* data = [[NSUserDefaults standardUserDefaults] objectForKey:defaultKey];
  if (data) {
    BOOL isStale;
    NSError* error = nil;
    NSURL* url = [NSURL URLByResolvingBookmarkData:data options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:&isStale error:&error];
    if (url) {
      if ([url startAccessingSecurityScopedResource]) {
#if 0  // TODO: This doesn't work on 10.9.1: re-saving a staled bookmark will be prevent it to be saved again if becoming staled again
        if (!isStale || [self _saveBookmark:defaultKey withURL:url]) {
          return url.path;
        }
#else
        return url.path;
#endif
      } else {
        NSLog(@"Failed accessing bookmark");
      }
    } else {
      NSLog(@"Failed resolving bookmark: %@", error);
    }
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:defaultKey];
  }
  return nil;
}

#endif

- (void)applicationDidFinishLaunching:(NSNotification*)notification {
#ifndef NDEBUG
  _leftPath = [self _loadBookmark:kUserDefaultKey_LeftBookmark];
  _rightPath = [self _loadBookmark:kUserDefaultKey_RightBookmark];
#endif
  [self _compareFolders:YES];
  
  [_mainWindow makeKeyAndOrderFront:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)application {
  return YES;
}

- (BOOL)panel:(id)sender shouldEnableURL:(NSURL*)url {
  BOOL isDirectory;
  return [[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDirectory] && isDirectory;
}

- (void)_selectFolder:(BOOL)isRight {
  NSOpenPanel* openPanel = [NSOpenPanel openPanel];
  openPanel.delegate = self;
  openPanel.canChooseFiles = YES;
  openPanel.canChooseDirectories = YES;
  if ([openPanel runModal] == NSFileHandlingPanelOKButton) {
    NSURL* url = [openPanel URL];
    if (isRight) {
      _rightPath = url.path;
    } else {
      _leftPath = url.path;
    }
    [self _compareFolders:YES];
#ifndef NDEBUG
    [self _saveBookmark:(isRight ? kUserDefaultKey_RightBookmark : kUserDefaultKey_LeftBookmark) withURL:url];
#endif
  }
}

- (IBAction)selectLeft:(id)sender {
  [self _selectFolder:NO];
}

- (IBAction)selectRight:(id)sender {
  [self _selectFolder:YES];
}

- (IBAction)updateFilters:(id)sender {
  [self _compareFolders:NO];
}

- (IBAction)updateComparison:(id)sender {
  [self _compareFolders:YES];
}

- (void)_revealItem:(BOOL)isRight {
  Row* row = _arrayController.selectedObjects.firstObject;
  NSString* path = (isRight ? row.rightItem.absolutePath : row.leftItem.absolutePath);
  if (path) {
    [[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:nil];
  }
}

- (IBAction)revealLeft:(id)sender {
  [self _revealItem:NO];
}

- (IBAction)revealRight:(id)sender {
  [self _revealItem:YES];
}

@end
