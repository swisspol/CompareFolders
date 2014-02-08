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

#import <AppKit/AppKit.h>
#import <StoreKit/StoreKit.h>

#import "DirectoryScanner.h"

#define kUserDefaultKey_FilterIdentical @"filterIdentical"
#define kUserDefaultKey_FilterHidden @"filterHidden"
#define kUserDefaultKey_FilterFile @"filterFile"
#define kUserDefaultKey_FilterFolder @"filterFolder"
#define kUserDefaultKey_SkipDate @"skipDate"
#define kUserDefaultKey_SkipPermission @"skipPermission"
#define kUserDefaultKey_SkipContent @"skipContent"
#define kUserDefaultKey_LeftBookmark @"leftBookmark"
#define kUserDefaultKey_RightBookmark @"rightBookmark"

#define kStoreKitProductIdentifier @"unlimited"

@interface TableView : NSTableView
@end

@interface Row : NSObject
@property(nonatomic) ComparisonResult result;
@property(nonatomic, retain) Item* leftItem;
@property(nonatomic, retain) Item* rightItem;
@property(nonatomic, readonly) BOOL differentPermissions;
@property(nonatomic, readonly) BOOL differentGroupID;
@property(nonatomic, readonly) BOOL differentUserID;
@property(nonatomic, readonly) BOOL differentCreationDates;
@property(nonatomic, readonly) BOOL differentModificationsDates;
@property(nonatomic, readonly) BOOL differentFileContents;
@end

@interface AppDelegate : NSObject <NSApplicationDelegate> {
@private
  NSString* _leftPath;
  NSString* _rightPath;
  NSMutableArray* _rows;
  BOOL _purchasing;
}
@property(nonatomic, getter = isReady) BOOL ready;
@property(nonatomic, assign) IBOutlet NSWindow* mainWindow;
@property(nonatomic, assign) IBOutlet NSTableView* tableView;
@property(nonatomic, assign) IBOutlet NSArrayController* arrayController;
- (IBAction)selectLeft:(id)sender;
- (IBAction)selectRight:(id)sender;
- (IBAction)updateFilters:(id)sender;
- (IBAction)updateComparison:(id)sender;
- (IBAction)revealLeft:(id)sender;
- (IBAction)revealRight:(id)sender;
@end

@interface AppDelegate (StoreKit) <SKPaymentTransactionObserver, SKProductsRequestDelegate>
- (void)purchase;
- (void)restore;
@end
