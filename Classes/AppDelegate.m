//  Copyright (C) 2014-2017 Pierre-Olivier Latour <info@pol-online.net>
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
#import "GARawTracker.h"
#if DEBUG
#import "XLAppKitOverlayLogger.h"
#endif

#define kUserDefaultKey_ChecksumFiles @"checksumFiles"

#define kUserDefaultKey_FilterIdentical @"filterIdentical"
#define kUserDefaultKey_FilterHidden @"filterHidden"
#define kUserDefaultKey_FilterFiles @"filterFiles"
#define kUserDefaultKey_FilterFolders @"filterFolders"
#define kUserDefaultKey_FilterLinks @"filterLinks"
#define kUserDefaultKey_FilterPermissions @"filterPermissions"
#define kUserDefaultKey_FilterCreations @"filterCreations"
#define kUserDefaultKey_FilterModifications @"filterModifications"

#if DEBUG
#define kUserDefaultKey_LeftBookmark @"leftBookmark"
#define kUserDefaultKey_RightBookmark @"rightBookmark"
#endif

#define kInAppProductIdentifier @"compare_folders_file_checksums"

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
    kUserDefaultKey_ChecksumFiles : @NO,
    kUserDefaultKey_FilterIdentical : @NO,
    kUserDefaultKey_FilterHidden : @NO,
    kUserDefaultKey_FilterFiles : @NO,
    kUserDefaultKey_FilterFolders : @NO,
    kUserDefaultKey_FilterLinks : @NO,
    kUserDefaultKey_FilterPermissions : @NO,
    kUserDefaultKey_FilterCreations : @NO,
    kUserDefaultKey_FilterModifications : @NO
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

- (void)_updateTableView {
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
        if (filterModifications) {
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

- (void)_compareFolders {
  BOOL checksumFiles = [[NSUserDefaults standardUserDefaults] boolForKey:kUserDefaultKey_ChecksumFiles];
  [_arrayController setContent:nil];
  _rows = nil;

  _stopComparison = NO;
  self.comparing = YES;
  ComparisonOptions options = 0;
  if (checksumFiles && [[InAppStore sharedStore] hasPurchasedProductWithIdentifier:kInAppProductIdentifier]) {
    options |= kComparisonOption_FileContent;
  }
#if DEBUG
  CFAbsoluteTime time = CFAbsoluteTimeGetCurrent();
#endif
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    @autoreleasepool {
      NSMutableArray* errors = [[NSMutableArray alloc] init];
      NSMutableArray* rows = [[NSMutableArray alloc] init];
      BOOL success = [[DirectoryScanner sharedScanner] compareOldDirectoryAtPath:_leftPath
          withNewDirectoryAtPath:_rightPath
          options:options
          excludeBlock:^BOOL(DirectoryItem* directory) {
            return _stopComparison;
          }
          resultBlock:^(ComparisonResult result, Item* item, Item* otherItem, BOOL* stop) {
            Row* row = [[Row alloc] init];
            row.result = result;
            row.leftItem = item;
            row.rightItem = otherItem;
            [rows addObject:row];
            *stop = _stopComparison;
          }
          errorBlock:^(NSError* error) {
            [errors addObject:error];
          }];
      dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
          if (success) {
            XLOG_DEBUG(@"Comparison done in %.3f seconds", CFAbsoluteTimeGetCurrent() - time);
          } else {
            XLOG_DEBUG(@"Comparison failed!");
          }
          self.comparing = NO;
          self.ready = success;
          if (success) {
            _rows = rows;
            [self _updateTableView];
          }
          if (errors.count && !_stopComparison) {
            [_errorController setContent:errors];
            [NSApp beginSheet:_errorWindow modalForWindow:_mainWindow modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
          }
        }
      });
    }
  });
}

#if DEBUG

- (BOOL)_saveBookmark:(NSString*)defaultKey withURL:(NSURL*)url {
  NSError* error = nil;
  NSData* data = [url bookmarkDataWithOptions:(NSURLBookmarkCreationWithSecurityScope | NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess) includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
  if (data) {
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:defaultKey];
    return YES;
  }
  XLOG_ERROR(@"Failed saving bookmark: %@", error);
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
        XLOG_ERROR(@"Failed accessing bookmark");
      }
    } else {
      XLOG_ERROR(@"Failed resolving bookmark: %@", error);
    }
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:defaultKey];
  }
  return nil;
}

#endif

- (void)applicationWillFinishLaunching:(NSNotification*)notification {
#if DEBUG
  [XLSharedFacility addLogger:[XLAppKitOverlayLogger sharedLogger]];
#endif

  [[GARawTracker sharedTracker] startWithTrackingID:@"UA-84346976-1"];
}

- (void)applicationDidFinishLaunching:(NSNotification*)notification {
  [[InAppStore sharedStore] setDelegate:self];
  if ([[InAppStore sharedStore] hasPurchasedProductWithIdentifier:kInAppProductIdentifier]) {
    [_tabView selectTabViewItemAtIndex:1];
  } else {
    [_tabView selectTabViewItemAtIndex:0];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kUserDefaultKey_ChecksumFiles];
  }

#if DEBUG
  self.leftPath = [self _loadBookmark:kUserDefaultKey_LeftBookmark];
  self.rightPath = [self _loadBookmark:kUserDefaultKey_RightBookmark];
  if (_leftPath && _rightPath) {
    [self _compareFolders];
  }
#endif

  [_mainWindow makeKeyAndOrderFront:nil];
}

- (void)applicationDidBecomeActive:(NSNotification*)notification {
  [[GARawTracker sharedTracker] sendEventWithCategory:@"application" action:@"activate" label:nil value:nil completionBlock:NULL];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication*)sender {
  if ([[InAppStore sharedStore] isPurchasing] || [[InAppStore sharedStore] isRestoring]) {
    return NSTerminateCancel;
  }
  return NSTerminateNow;
}

- (BOOL)windowShouldClose:(id)sender {
  [NSApp terminate:nil];
  return NO;
}

- (BOOL)validateMenuItem:(NSMenuItem*)menuItem {
  if ((menuItem.action == @selector(purchaseFeature:)) || (menuItem.action == @selector(restorePurchases:))) {
    return ![[InAppStore sharedStore] hasPurchasedProductWithIdentifier:kInAppProductIdentifier] && ![[InAppStore sharedStore] isPurchasing] && ![[InAppStore sharedStore] isRestoring];
  }
  return YES;
}

- (void)inAppStore:(InAppStore*)store didPurchaseProductWithIdentifier:(NSString*)identifier {
  [_tabView selectTabViewItemAtIndex:1];
  if ([[InAppStore sharedStore] isPurchasing]) {
    NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"ALERT_PURCHASE_TITLE", nil)
                                     defaultButton:NSLocalizedString(@"ALERT_PURCHASE_DEFAULT_BUTTON", nil)
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:NSLocalizedString(@"ALERT_PURCHASE_MESSAGE", nil)];
    [alert beginSheetModalForWindow:_mainWindow modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
  }
}

- (void)inAppStore:(InAppStore*)store didRestoreProductWithIdentifier:(NSString*)identifier {
  if ([identifier isEqualToString:kInAppProductIdentifier]) {
    [_tabView selectTabViewItemAtIndex:1];
    if ([[InAppStore sharedStore] isRestoring]) {
      [NSApp activateIgnoringOtherApps:YES];
      NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"ALERT_RESTORE_TITLE", nil)
                                       defaultButton:NSLocalizedString(@"ALERT_RESTORE_DEFAULT_BUTTON", nil)
                                     alternateButton:nil
                                         otherButton:nil
                           informativeTextWithFormat:NSLocalizedString(@"ALERT_RESTORE_MESSAGE", nil)];
      [alert beginSheetModalForWindow:_mainWindow modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
    }
  }
}

- (void)_reportIAPError:(NSError*)error {
  [NSApp activateIgnoringOtherApps:YES];
  NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"ALERT_IAP_FAILED_TITLE", nil)
                                   defaultButton:NSLocalizedString(@"ALERT_IAP_FAILED_BUTTON", nil)
                                 alternateButton:nil
                                     otherButton:nil
                       informativeTextWithFormat:NSLocalizedString(@"ALERT_IAP_FAILED_MESSAGE", nil), error.localizedDescription];
  [alert beginSheetModalForWindow:_mainWindow modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (void)inAppStore:(InAppStore*)store didFailFindingProductWithIdentifier:(NSString*)identifier {
  [self _reportIAPError:nil];
}

- (void)inAppStore:(InAppStore*)store didFailPurchasingProductWithIdentifier:(NSString*)identifier error:(NSError*)error {
  [self _reportIAPError:error];
}

- (void)inAppStore:(InAppStore*)store didFailRestoreWithError:(NSError*)error {
  [self _reportIAPError:error];
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
      self.rightPath = url.path;
    } else {
      self.leftPath = url.path;
    }
#if DEBUG
    [self _saveBookmark:(isRight ? kUserDefaultKey_RightBookmark : kUserDefaultKey_LeftBookmark)withURL:url];
#endif
    if (_leftPath && _rightPath) {
      [self _compareFolders];
    }
  }
}

- (IBAction)selectLeftFolder:(id)sender {
  [self _selectFolder:NO];
}

- (IBAction)selectRightFolder:(id)sender {
  [self _selectFolder:YES];
}

- (IBAction)updateComparison:(id)sender {
  [self _compareFolders];
}

- (IBAction)stopComparison:(id)sender {
  if (_stopComparison == NO) {
    _stopComparison = YES;
  }
}

- (IBAction)toggleFileChecksums:(id)sender {
  if (_leftPath && _rightPath) {
    [self _compareFolders];
  }
}

- (IBAction)updateFilters:(id)sender {
  [self _updateTableView];
}

- (void)_revealItem:(BOOL)isRight {
  Row* row = _arrayController.selectedObjects.firstObject;
  NSString* path = (isRight ? row.rightItem.absolutePath : row.leftItem.absolutePath);
  if (path) {
    [[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:@""];
  }
}

- (IBAction)revealLeft:(id)sender {
  [self _revealItem:NO];
}

- (IBAction)revealRight:(id)sender {
  [self _revealItem:YES];
}

- (IBAction)purchaseFeature:(id)sender {
  if (![[InAppStore sharedStore] purchaseProductWithIdentifier:kInAppProductIdentifier]) {
    NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"ALERT_UNAVAILABLE_TITLE", nil)
                                     defaultButton:NSLocalizedString(@"ALERT_UNAVAILABLE_DEFAULT_BUTTON", nil)
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:NSLocalizedString(@"ALERT_UNAVAILABLE_MESSAGE", nil)];
    [alert beginSheetModalForWindow:_mainWindow modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
  }
}

- (IBAction)restorePurchases:(id)sender {
  [[InAppStore sharedStore] restorePurchases];
}

- (void)_purchaseAlertDidEnd:(NSAlert*)alert returnCode:(NSInteger)returnCode contextInfo:(void*)contextInfo {
  if (returnCode == NSAlertDefaultReturn) {
    [self purchaseFeature:nil];
  }
}

- (IBAction)learnMore:(id)sender {
  NSAlert* alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"ALERT_LEARN_TITLE", nil)]
                                   defaultButton:NSLocalizedString(@"ALERT_LEARN_DEFAULT_BUTTON", nil)
                                 alternateButton:NSLocalizedString(@"ALERT_LEARN_ALTERNATE_BUTTON", nil)
                                     otherButton:nil
                       informativeTextWithFormat:NSLocalizedString(@"ALERT_LEARN_MESSAGE", nil)];
  [alert beginSheetModalForWindow:_mainWindow modalDelegate:self didEndSelector:@selector(_purchaseAlertDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (IBAction)dismissErrors:(id)sender {
  [NSApp endSheet:_errorWindow];
  [_errorWindow orderOut:nil];
  [_errorController setContent:nil];
}

@end
