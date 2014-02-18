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

#import "DirectoryScanner.h"
#import "InAppStore.h"

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
@property(nonatomic, readonly) BOOL differentFileDataSizes;
@property(nonatomic, readonly) BOOL differentFileResourceSizes;
@end

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate, NSOpenSavePanelDelegate, InAppStoreDelegate> {
@private
  NSArray* _rows;
  BOOL _stopComparison;
}
@property(nonatomic, assign) IBOutlet NSWindow* mainWindow;
@property(nonatomic, assign) IBOutlet NSTableView* tableView;
@property(nonatomic, assign) IBOutlet NSArrayController* arrayController;
@property(nonatomic, assign) IBOutlet NSTabView* tabView;
@property(nonatomic, assign) IBOutlet NSWindow* errorWindow;
@property(nonatomic, assign) IBOutlet NSArrayController* errorController;
@property(nonatomic, copy) NSString* leftPath;
@property(nonatomic, copy) NSString* rightPath;
@property(nonatomic, getter = isComparing) BOOL comparing;
@property(nonatomic, getter = isReady) BOOL ready;
- (IBAction)selectLeftFolder:(id)sender;
- (IBAction)selectRightFolder:(id)sender;
- (IBAction)updateComparison:(id)sender;
- (IBAction)stopComparison:(id)sender;
- (IBAction)toggleFileChecksums:(id)sender;
- (IBAction)updateFilters:(id)sender;
- (IBAction)revealLeft:(id)sender;
- (IBAction)revealRight:(id)sender;
- (IBAction)purchaseFeature:(id)sender;
- (IBAction)restorePurchases:(id)sender;
- (IBAction)learnMore:(id)sender;
- (IBAction)dismissErrors:(id)sender;
@end
