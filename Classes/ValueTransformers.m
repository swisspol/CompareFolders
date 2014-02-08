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

#import "ValueTransformers.h"
#import <sys/stat.h>
#import <pwd.h>
#import <grp.h>

#import "DirectoryScanner.h"

@implementation PathIconTransformer

+ (Class)transformedValueClass {
  return [NSImage class];
}

+ (BOOL)allowsReverseTransformation {
  return NO;
}

- (id)transformedValue:(id)value {
  if (value) {
    NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFile:value];
    icon.size = NSMakeSize(128, 128);  // Must match UIImageView size in IB
    return icon;
  }
  return nil;
}

@end

@implementation FileSizeTransformer

+ (Class)transformedValueClass {
  return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
  return NO;
}

- (id)init {
  if ((self = [super init])) {
    _formatter = [[NSNumberFormatter alloc] init];
    _formatter.numberStyle = NSNumberFormatterDecimalStyle;
  }
  return self;
}

- (id)transformedValue:(id)value {
  if (value) {
    unsigned long long size = [value unsignedLongLongValue];
    if (size < 1000) {  // 1 KB
      return [NSString stringWithFormat:NSLocalizedString(@"FILE_SIZE_B", nil), [_formatter stringFromNumber:value]];
    } else if (size < 1000 * 1000) {  // 1 MB
      return [NSString stringWithFormat:NSLocalizedString(@"FILE_SIZE_KB", nil), [_formatter stringForObjectValue:value], [_formatter stringFromNumber:[NSNumber numberWithDouble:(round((double)size / 100.0) / 10.0)]]];
    } else if (size < 1000 * 1000 * 1000) {  // 1 GB
      return [NSString stringWithFormat:NSLocalizedString(@"FILE_SIZE_MB", nil), [_formatter stringForObjectValue:value], [_formatter stringFromNumber:[NSNumber numberWithDouble:(round((double)size / (100.0 * 1000.0)) / 10.0)]]];
    } else {  // 1+ GB
      return [NSString stringWithFormat:NSLocalizedString(@"FILE_SIZE_GB", nil), [_formatter stringForObjectValue:value], [_formatter stringFromNumber:[NSNumber numberWithDouble:(round((double)size / (100.0 * 1000.0 * 1000.0)) / 10.0)]]];
    }
  }
  return nil;
}

@end

@implementation UserIDTransformer

+ (Class)transformedValueClass {
  return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
  return NO;
}

- (id)transformedValue:(id)value {
  if (value) {
    struct passwd* info = getpwuid([value unsignedIntValue]);
    return info ? [NSString stringWithUTF8String:info->pw_name] : nil;
  }
  return nil;
}

@end

@implementation GroupIDTransformer

+ (Class)transformedValueClass {
  return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
  return NO;
}

- (id)transformedValue:(id)value {
  if (value) {
    struct group* info = getgrgid([value unsignedIntValue]);
    return info ? [NSString stringWithUTF8String:info->gr_name] : nil;
  }
  return nil;
}

@end

@implementation PermissionsTransformer

+ (Class)transformedValueClass {
  return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
  return NO;
}

- (id)transformedValue:(id)value {
  if (value) {
    short perms = [value shortValue];
    char string[10];
    string[0] = perms & S_IRUSR ? 'r' : '-';
    string[1] = perms & S_IWUSR ? 'w' : '-';
    string[2] = perms & S_IXUSR ? 'x' : '-';
    string[3] = perms & S_IRGRP ? 'r' : '-';
    string[4] = perms & S_IWGRP ? 'w' : '-';
    string[5] = perms & S_IXGRP ? 'x' : '-';
    string[6] = perms & S_IROTH ? 'r' : '-';
    string[7] = perms & S_IWOTH ? 'w' : '-';
    string[8] = perms & S_IXOTH ? 'x' : '-';
    string[9] = 0;
    return [NSString stringWithUTF8String:string];
  }
  return nil;
}

@end

@implementation DifferenceTransformer

+ (Class)transformedValueClass {
  return [NSColor class];
}

+ (BOOL)allowsReverseTransformation {
  return NO;
}

- (id)transformedValue:(id)value {
  return [value boolValue] ? [NSColor redColor] : [NSColor darkGrayColor];
}

@end

@implementation ItemIconTransformer

+ (Class)transformedValueClass {
  return [NSImage class];
}

+ (BOOL)allowsReverseTransformation {
  return NO;
}

- (id)transformedValue:(id)value {
  if ([value isFile]) {
    return [NSImage imageNamed:@"File"];
  }
  if ([value isDirectory]) {
    return [NSImage imageNamed:@"Folder"];
  }
  if ([value isSymLink]) {
    return [NSImage imageNamed:@"Link"];
  }
  return nil;
}

@end
