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

- (void)drawRow:(NSInteger)row clipRect:(NSRect)clipRect {
  if (row != [self selectedRow]) {
    NSArrayController* controller = [(AppDelegate*)[NSApp delegate] arrayController];
    ComparisonResult result = [(Row*)[controller.arrangedObjects objectAtIndex:row] result];
    NSColor* color;
    if (result & (kComparisonResult_Removed | kComparisonResult_Added | kComparisonResult_Replaced | kComparisonResult_Modified_FileContent)) {
      color = row % 2 ? _rowColors[2] : _rowColors[3];
    } else if (result & kComparisonResult_ModifiedMask) {
      color = row % 2 ? _rowColors[0] : _rowColors[1];
    } else {
      color = row % 2 ? _rowColors[4] : _rowColors[5];
    }
    [color setFill];
    NSRectFill([self rectOfRow:row]);
  }
  [super drawRow:row clipRect:clipRect];
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

- (BOOL)differentFileContents {
  return _result & kComparisonResult_Modified_FileContent ? YES : NO;
}

@end

@implementation AppDelegate

+ (void)initialize {
  NSDictionary* defaults = @{
                             kUserDefaultKey_FilterIdentical: @NO,
                             kUserDefaultKey_FilterHidden: @NO,
                             kUserDefaultKey_FilterFiles: @NO,
                             kUserDefaultKey_FilterFolders: @NO,
                             kUserDefaultKey_FilterLinks: @NO,
                             kUserDefaultKey_SkipDate: @NO,
                             kUserDefaultKey_SkipPermission: @NO,
                             kUserDefaultKey_SkipContent: @NO
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
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kUserDefaultKey_SkipDate]) {
      options |= kComparisonOption_Dates;
    }
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kUserDefaultKey_SkipPermission]) {
      options |= kComparisonOption_Ownership;
    }
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kUserDefaultKey_SkipContent]) {
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
      if (filterHidden || filterIdentical || filterFiles || filterFolders || filterLinks) {
        NSMutableArray* array = [[NSMutableArray alloc] initWithCapacity:_rows.count];
        for (Row* row in _rows) {
          Item* leftItem = row.leftItem;
          Item* rightItem = row.rightItem;
          if (filterHidden && ([leftItem.name hasPrefix:@"."] || [rightItem.name hasPrefix:@"."])) {
            continue;
          }
          if (filterIdentical && !row.result) {
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
          [array addObject:row];
        }
        [_arrayController setContent:array];
      } else {
        [_arrayController setContent:_rows];
      }
    }
  }
}

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

- (void)applicationDidFinishLaunching:(NSNotification*)notification {
  [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
  
  _leftPath = [self _loadBookmark:kUserDefaultKey_LeftBookmark];
  _rightPath = [self _loadBookmark:kUserDefaultKey_RightBookmark];
  [self _compareFolders:YES];
  
  [_mainWindow makeKeyAndOrderFront:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)application {
  return YES;
}

- (void)_selectFolder:(BOOL)isRight {
  NSOpenPanel* openPanel = [NSOpenPanel openPanel];
  [openPanel setCanChooseFiles:NO];
  [openPanel setCanChooseDirectories:YES];
  if ([openPanel runModal] == NSFileHandlingPanelOKButton) {
    NSURL* url = [openPanel URL];
    if (isRight) {
      _rightPath = url.path;
    } else {
      _leftPath = url.path;
    }
    [self _compareFolders:YES];
    [self _saveBookmark:(isRight ? kUserDefaultKey_RightBookmark : kUserDefaultKey_LeftBookmark) withURL:url];
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

@implementation AppDelegate (StoreKit)

//  NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"ALERT_DATABASE_TITLE", nil) defaultButton:NSLocalizedString(@"ALERT_DATABASE_BUTTON", nil) alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedString(@"ALERT_DATABASE_MESSAGE", nil)];
//  [alert runModal];

- (void) _startPurchase {
  _purchasing = YES;
//  [self showSpinnerWithMessage:NSLocalizedString(@"PURCHASE_SPINNER", nil) fullScreen:YES animated:YES];
//  self.window.userInteractionEnabled = NO;
}

- (void) _finishPurchase {
//  DCHECK(_purchasing);
//  self.window.userInteractionEnabled = YES;
//  [self hideSpinner:YES];
  _purchasing = NO;
}

- (void) purchase {
//  DCHECK([[NSUserDefaults standardUserDefaults] integerForKey:kDefaultKey_ServerMode] != kServerMode_Full);
//  if (![[NetReachability sharedNetReachability] state]) {
//    [self showAlertWithTitle:NSLocalizedString(@"OFFLINE_ALERT_TITLE", nil) message:NSLocalizedString(@"OFFLINE_ALERT_MESSAGE", nil) button:NSLocalizedString(@"OFFLINE_ALERT_BUTTON", nil)];
//    return;
//  }
  if (![SKPaymentQueue canMakePayments]) {
//    [self showAlertWithTitle:NSLocalizedString(@"DISABLED_ALERT_TITLE", nil) message:NSLocalizedString(@"DISABLED_ALERT_MESSAGE", nil) button:NSLocalizedString(@"DISABLED_ALERT_BUTTON", nil)];
    return;
  }
  if (_purchasing || [[[SKPaymentQueue defaultQueue] transactions] count]) {
//    [self showAlertWithTitle:NSLocalizedString(@"BUSY_ALERT_TITLE", nil) message:NSLocalizedString(@"BUSY_ALERT_MESSAGE", nil) button:NSLocalizedString(@"BUSY_ALERT_BUTTON", nil)];
    return;
  }
  SKProductsRequest* request = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithObject:kStoreKitProductIdentifier]];
  request.delegate = self;
  [request start];
  [self _startPurchase];
}

- (void) restore {
//  DCHECK([[NSUserDefaults standardUserDefaults] integerForKey:kDefaultKey_ServerMode] != kServerMode_Full);
  [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
  [self _startPurchase];
}

- (void) request:(SKRequest*)request didFailWithError:(NSError*)error {
  NSLog(@"App Store request failed: %@", error);
//  [self showAlertWithTitle:NSLocalizedString(@"FAILED_ALERT_TITLE", nil) message:NSLocalizedString(@"FAILED_ALERT_MESSAGE", nil) button:NSLocalizedString(@"FAILED_ALERT_BUTTON", nil)];
  [self _finishPurchase];
}

- (void) productsRequest:(SKProductsRequest*)request didReceiveResponse:(SKProductsResponse*)response {
  SKProduct* product = [response.products firstObject];
  if (product) {
    SKPayment* payment = [SKPayment paymentWithProduct:product];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
  } else {
    NSLog(@"Invalid App Store products: %@", response.invalidProductIdentifiers);
//    [self showAlertWithTitle:NSLocalizedString(@"FAILED_ALERT_TITLE", nil) message:NSLocalizedString(@"FAILED_ALERT_MESSAGE", nil) button:NSLocalizedString(@"FAILED_ALERT_BUTTON", nil)];
    [self _finishPurchase];
  }
}

// This can be called in response to a purchase request or on app cold launch if there are unfinished transactions still pending
- (void) paymentQueue:(SKPaymentQueue*)queue updatedTransactions:(NSArray*)transactions {
  NSLog(@"%lu App Store transactions updated", (unsigned long)transactions.count);
  for (SKPaymentTransaction* transaction in transactions) {
    NSString* productIdentifier = transaction.payment.productIdentifier;
//    DCHECK(productIdentifier);
    switch (transaction.transactionState) {
        
      case SKPaymentTransactionStatePurchasing:
//        [self logEvent:@"iap.purchasing" withParameterName:@"product" value:productIdentifier];
        break;
        
      case SKPaymentTransactionStatePurchased:
      case SKPaymentTransactionStateRestored: {
        NSLog(@"Processing App Store transaction '%@' from %@", transaction.transactionIdentifier, transaction.transactionDate);
        if ([productIdentifier isEqualToString:kStoreKitProductIdentifier]) {
//          NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
//          [defaults setInteger:kServerMode_Full forKey:kDefaultKey_ServerMode];
//          [defaults removeObjectForKey:kDefaultKey_UploadsRemaining];
//          [defaults synchronize];
        } else {
          NSLog(@"Unexpected App Store product \"%@\"", productIdentifier);
//          DNOT_REACHED();
        }
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        if (transaction.transactionState == SKPaymentTransactionStatePurchased) {
//          [(LibraryViewController*)self.viewController updatePurchase];
//          [self showAlertWithTitle:NSLocalizedString(@"COMPLETE_ALERT_TITLE", nil) message:NSLocalizedString(@"COMPLETE_ALERT_MESSAGE", nil) button:NSLocalizedString(@"COMPLETE_ALERT_BUTTON", nil)];
          [self _finishPurchase];
//          [self logEvent:@"iap.purchased" withParameterName:@"product" value:productIdentifier];
        } else {
//          DCHECK(_purchasing == NO);
//          [self logEvent:@"iap.restored" withParameterName:@"product" value:productIdentifier];
        }
        break;
      }
        
      case SKPaymentTransactionStateFailed: {
        NSError* error = transaction.error;
        if ([error.domain isEqualToString:SKErrorDomain] && (error.code == SKErrorPaymentCancelled)) {
          NSLog(@"App Store transaction cancelled");
//          [self logEvent:@"iap.cancelled" withParameterName:@"product" value:productIdentifier];
        } else {
          NSLog(@"App Store transaction failed: %@", error);
//          [self showAlertWithTitle:NSLocalizedString(@"FAILED_ALERT_TITLE", nil) message:NSLocalizedString(@"FAILED_ALERT_MESSAGE", nil) button:NSLocalizedString(@"FAILED_ALERT_BUTTON", nil)];
//          [self logEvent:@"iap.failed" withParameterName:@"product" value:productIdentifier];
        }
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        [self _finishPurchase];
        break;
      }
        
    }
  }
}

- (void)paymentQueue:(SKPaymentQueue*)queue removedTransactions:(NSArray*)transactions {
  NSLog(@"%lu App Store transactions removed", (unsigned long)transactions.count);
}

- (void)paymentQueue:(SKPaymentQueue*)queue restoreCompletedTransactionsFailedWithError:(NSError*)error {
  if ([error.domain isEqualToString:SKErrorDomain] && (error.code == SKErrorPaymentCancelled)) {
    NSLog(@"App Store transaction restoration cancelled");
  } else {
    NSLog(@"App Store transaction restoration failed: %@", error);
  }
  [self _finishPurchase];
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue*)queue {
  NSLog(@"App Store transactions restored");
  [self _finishPurchase];
}

@end
