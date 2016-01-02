//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "LMViewBuilder.h"
#import "UIView+Markup.h"

#import <objc/message.h>

static NSString * const kNormalSizeClass = @"normal";
static NSString * const kHorizontalSizeClass = @"horizontal";
static NSString * const kVerticalSizeClass = @"vertical";
static NSString * const kMinimalSizeClass = @"minimal";

static NSString * const kSizeClassFormat = @"%@~%@";
static NSString * const kFileExtension = @"xml";

static NSString * const kPropertiesTarget = @"properties";
static NSString * const kStringsTarget = @"strings";

static NSString * const kRootTag = @"root";
static NSString * const kFactoryKey = @"style";
static NSString * const kTemplateKey = @"class";

static NSString * const kOutletKey = @"id";
static NSString * const kActionPrefix = @"on";

static NSString * const kLocalizedStringPrefix = @"@";

@interface LMViewBuilder () <NSXMLParserDelegate>

@end

@implementation LMViewBuilder
{
    id _owner;
    UIView *_root;

    NSMutableDictionary *_properties;
    NSMutableDictionary *_strings;

    NSMutableArray *_views;
}

+ (UIView *)viewWithName:(NSString *)name owner:(id)owner root:(UIView *)root
{
    NSBundle *mainBundle = [NSBundle mainBundle];

    NSURL *url = nil;

    if ([owner conformsToProtocol:@protocol(UITraitEnvironment)]) {
        UITraitCollection *traitCollection = [owner traitCollection];

        UIUserInterfaceSizeClass horizontalSizeClass = [traitCollection horizontalSizeClass];
        UIUserInterfaceSizeClass verticalSizeClass = [traitCollection verticalSizeClass];

        NSString *sizeClass;
        if (horizontalSizeClass == UIUserInterfaceSizeClassRegular && verticalSizeClass == UIUserInterfaceSizeClassRegular) {
            sizeClass = kNormalSizeClass;
        } else if (horizontalSizeClass == UIUserInterfaceSizeClassRegular && verticalSizeClass == UIUserInterfaceSizeClassCompact) {
            sizeClass = kHorizontalSizeClass;
        } else if (horizontalSizeClass == UIUserInterfaceSizeClassCompact && verticalSizeClass == UIUserInterfaceSizeClassRegular) {
            sizeClass = kVerticalSizeClass;
        } else {
            sizeClass = kMinimalSizeClass;
        }

        url = [mainBundle URLForResource:[NSString stringWithFormat:kSizeClassFormat, name, sizeClass] withExtension:kFileExtension];
    }

    if (url == nil) {
        url = [mainBundle URLForResource:name withExtension:kFileExtension];
    }

    UIView *view = nil;

    if (url != nil) {
        LMViewBuilder *viewBuilder = [[LMViewBuilder alloc] initWithOwner:owner root:root];

        NSXMLParser *parser = [[NSXMLParser alloc] initWithContentsOfURL:url];

        [parser setDelegate:viewBuilder];
        [parser parse];

        view = [viewBuilder root];
    }

    return view;
}

+ (UIColor *)colorValue:(NSString *)value
{
    UIColor *color = nil;

    if ([value hasPrefix:@"#"]) {
        if ([value length] < 9) {
            value = [NSString stringWithFormat:@"%@ff", value];
        }

        if ([value length] == 9) {
            int red, green, blue, alpha;
            sscanf([value UTF8String], "#%02X%02X%02X%02X", &red, &green, &blue, &alpha);

            color = [UIColor colorWithRed:red / 255.0 green:green / 255.0 blue:blue / 255.0 alpha:alpha / 255.0];
        }
    }

    return color;
}

+ (UIFont *)fontValue:(NSString *)value
{
    UIFont *font = nil;

    if ([value isEqual:@"title1"]) {
        font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle1];
    } else if ([value isEqual:@"title2"]) {
        font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle2];
    } else if ([value isEqual:@"title3"]) {
        font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle3];
    } else if ([value isEqual:@"headline"]) {
        font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    } else if ([value isEqual:@"subheadline"]) {
        font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    } else if ([value isEqual:@"body"]) {
        font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    } else if ([value isEqual:@"footnote"]) {
        font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    } else if ([value isEqual:@"caption1"]) {
        font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    } else if ([value isEqual:@"caption2"]) {
        font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
    } else {
        NSArray *components = [value componentsSeparatedByString:@" "];

        if ([components count] == 2) {
            NSString *fontName = [components objectAtIndex:0];
            CGFloat fontSize = [[components objectAtIndex:1] floatValue];

            if ([fontName isEqual:@"System"]) {
                font = [UIFont systemFontOfSize:fontSize];
            } else if ([fontName isEqual:@"System-Bold"]) {
                font = [UIFont boldSystemFontOfSize:fontSize];
            } else if ([fontName isEqual:@"System-Italic"]) {
                font = [UIFont italicSystemFontOfSize:fontSize];
            } else {
                font = [UIFont fontWithName:fontName size:fontSize];
            }
        }
    }

    return font;
}

+ (void)applyPropertyValues:(NSDictionary *)properties toView:(UIView *)view
{
    for (NSString *path in properties) {
        id value = [properties objectForKey:path];

        NSRange keyDelimiterRange = [path rangeOfString:@"." options:NSBackwardsSearch];

        NSString *key = (keyDelimiterRange.location == NSNotFound) ? path : [path substringFromIndex:keyDelimiterRange.location + 1];

        if ([key isEqual:@"contentMode"]) {
            // Translate to content mode
            UIViewContentMode contentMode;
            if ([value isEqual:@"scaleToFill"]) {
                contentMode = UIViewContentModeScaleToFill;
            } else if ([value isEqual:@"scaleAspectFit"]) {
                contentMode = UIViewContentModeScaleAspectFit;
            } else if ([value isEqual:@"scaleAspectFill"]) {
                contentMode = UIViewContentModeScaleAspectFill;
            } else if ([value isEqual:@"redraw"]) {
                contentMode = UIViewContentModeRedraw;
            } else if ([value isEqual:@"center"]) {
                contentMode = UIViewContentModeCenter;
            } else if ([value isEqual:@"top"]) {
                contentMode = UIViewContentModeTop;
            } else if ([value isEqual:@"bottom"]) {
                contentMode = UIViewContentModeBottom;
            } else if ([value isEqual:@"left"]) {
                contentMode = UIViewContentModeLeft;
            } else if ([value isEqual:@"right"]) {
                contentMode = UIViewContentModeRight;
            } else if ([value isEqual:@"topLeft"]) {
                contentMode = UIViewContentModeTopLeft;
            } else if ([value isEqual:@"topRight"]) {
                contentMode = UIViewContentModeTopRight;
            } else if ([value isEqual:@"bottomLeft"]) {
                contentMode = UIViewContentModeBottomLeft;
            } else if ([value isEqual:@"bottomRight"]) {
                contentMode = UIViewContentModeBottomRight;
            } else {
                continue;
            }

            value = [NSNumber numberWithInt:contentMode];
        } else if ([key isEqual:@"tintAdjustmentMode"]) {
            // Translate to tint adjustment mode
            UIViewTintAdjustmentMode tintAdjustmentMode;
            if ([value isEqual:@"automatic"]) {
                tintAdjustmentMode = UIViewTintAdjustmentModeAutomatic;
            } else if ([value isEqual:@"normal"]) {
                tintAdjustmentMode = UIViewTintAdjustmentModeNormal;
            } else if ([value isEqual:@"dimmed"]) {
                tintAdjustmentMode = UIViewTintAdjustmentModeDimmed;
            } else {
                continue;
            }

            value = [NSNumber numberWithInt:tintAdjustmentMode];
        } else if ([key isEqual:@"contentHorizontalAlignment"]) {
            // Translate to control content horizontal alignment
            UIControlContentHorizontalAlignment controlContentHorizontalAlignment;
            if ([value isEqual:@"center"]) {
                controlContentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
            } else if ([value isEqual:@"left"]) {
                controlContentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
            } else if ([value isEqual:@"right"]) {
                controlContentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
            } else if ([value isEqual:@"fill"]) {
                controlContentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
            } else {
                continue;
            }

            value = [NSNumber numberWithInt:controlContentHorizontalAlignment];
        } else if ([key isEqual:@"contentVerticalAlignment"]) {
            // Translate to control content vertical alignment
            UIControlContentVerticalAlignment controlContentVerticalAlignment;
            if ([value isEqual:@"center"]) {
                controlContentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
            } else if ([value isEqual:@"top"]) {
                controlContentVerticalAlignment = UIControlContentVerticalAlignmentTop;
            } else if ([value isEqual:@"bottom"]) {
                controlContentVerticalAlignment = UIControlContentVerticalAlignmentBottom;
            } else if ([value isEqual:@"fill"]) {
                controlContentVerticalAlignment = UIControlContentVerticalAlignmentFill;
            } else {
                continue;
            }

            value = [NSNumber numberWithInt:controlContentVerticalAlignment];
        } else if ([key isEqual:@"lineBreakMode"]) {
            // Translate to line break mode
            NSLineBreakMode lineBreakMode;
            if ([value isEqual:@"byWordWrapping"]) {
                lineBreakMode = NSLineBreakByWordWrapping;
            } else if ([value isEqual:@"byCharWrapping"]) {
                lineBreakMode = NSLineBreakByCharWrapping;
            } else if ([value isEqual:@"byClipping"]) {
                lineBreakMode = NSLineBreakByClipping;
            } else if ([value isEqual:@"byTruncatingHead"]) {
                lineBreakMode = NSLineBreakByTruncatingHead;
            } else if ([value isEqual:@"byTruncatingTail"]) {
                lineBreakMode = NSLineBreakByTruncatingTail;
            } else if ([value isEqual:@"byTruncatingMiddle"]) {
                lineBreakMode = NSLineBreakByTruncatingMiddle;
            } else {
                continue;
            }

            value = [NSNumber numberWithInt:lineBreakMode];
        } else if ([key isEqual:@"textAlignment"]) {
            // Translate value to text alignment
            NSTextAlignment textAlignment;
            if ([value isEqual:@"left"]) {
                textAlignment = NSTextAlignmentLeft;
            } else if ([value isEqual:@"center"]) {
                textAlignment = NSTextAlignmentCenter;
            } else if ([value isEqual:@"right"]) {
                textAlignment = NSTextAlignmentRight;
            } else if ([value isEqual:@"justified"]) {
                textAlignment = NSTextAlignmentJustified;
            } else if ([value isEqual:@"natural"]) {
                textAlignment = NSTextAlignmentNatural;
            } else {
                continue;
            }

            value = [NSNumber numberWithInt:textAlignment];
        } else if ([key isEqual:@"borderStyle"]) {
            // Translate to text border style
            UITextBorderStyle textBorderStyle;
            if ([value isEqual:@"none"]) {
                textBorderStyle = UITextBorderStyleNone;
            } else if ([value isEqual:@"line"]) {
                textBorderStyle = UITextBorderStyleLine;
            } else if ([value isEqual:@"bezel"]) {
                textBorderStyle = UITextBorderStyleBezel;
            } else if ([value isEqual:@"roundedRect"]) {
                textBorderStyle = UITextBorderStyleRoundedRect;
            } else {
                continue;
            }

            value = [NSNumber numberWithInt:textBorderStyle];
        } else if ([key isEqual:@"clearButtonMode"] || [key isEqual:@"leftViewMode"] || [key isEqual:@"rightViewMode"]) {
            // Translate to text field view mode
            UITextFieldViewMode textFieldViewMode;
            if ([value isEqual:@"never"]) {
                textFieldViewMode = UITextFieldViewModeNever;
            } else if ([value isEqual:@"whileEditing"]) {
                textFieldViewMode = UITextFieldViewModeWhileEditing;
            } else if ([value isEqual:@"unlessEditing"]) {
                textFieldViewMode = UITextFieldViewModeUnlessEditing;
            } else if ([value isEqual:@"always"]) {
                textFieldViewMode = UITextFieldViewModeAlways;
            } else {
                continue;
            }

            value = [NSNumber numberWithInt:textFieldViewMode];
        } else if ([key isEqual:@"autocapitalizationType"]) {
            // Translate to auto-capitalization type
            UITextAutocapitalizationType textAutocapitalizationType;
            if ([value isEqual:@"none"]) {
                textAutocapitalizationType = UITextAutocapitalizationTypeNone;
            } else if ([value isEqual:@"words"]) {
                textAutocapitalizationType = UITextAutocapitalizationTypeWords;
            } else if ([value isEqual:@"sentences"]) {
                textAutocapitalizationType = UITextAutocapitalizationTypeSentences;
            } else if ([value isEqual:@"allCharacters"]) {
                textAutocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
            } else {
                continue;
            }

            // Property is not KVC-compliant
            [(UIView<UITextInputTraits> *)view setAutocapitalizationType:textAutocapitalizationType];

            continue;
        } else if ([key isEqual:@"autocorrectionType"]) {
            // Translate to auto-correction type
            UITextAutocorrectionType textAutocorrectionType;
            if ([value isEqual:@"default"]) {
                textAutocorrectionType = UITextAutocorrectionTypeDefault;
            } else if ([value isEqual:@"yes"]) {
                textAutocorrectionType = UITextAutocorrectionTypeYes;
            } else if ([value isEqual:@"no"]) {
                textAutocorrectionType = UITextAutocorrectionTypeNo;
            } else {
                continue;
            }

            // Property is not KVC-compliant
            [(UIView<UITextInputTraits> *)view setAutocorrectionType:textAutocorrectionType];

            continue;
        } else if ([key isEqual:@"spellCheckingType"]) {
            // Translate to spell checking type
            UITextSpellCheckingType textSpellCheckingType;
            if ([value isEqual:@"default"]) {
                textSpellCheckingType = UITextSpellCheckingTypeDefault;
            } else if ([value isEqual:@"yes"]) {
                textSpellCheckingType = UITextSpellCheckingTypeYes;
            } else if ([value isEqual:@"no"]) {
                textSpellCheckingType = UITextSpellCheckingTypeNo;
            } else {
                continue;
            }

            // Property is not KVC-compliant
            [(UIView<UITextInputTraits> *)view setSpellCheckingType:textSpellCheckingType];

            continue;
        } else if ([key isEqual:@"keyboardAppearance"]) {
            // Translate to keyboard appearance
            UIKeyboardAppearance keyboardAppearance;
            if ([value isEqual:@"default"]) {
                keyboardAppearance = UIKeyboardAppearanceDefault;
            } else if ([value isEqual:@"dark"]) {
                keyboardAppearance = UIKeyboardAppearanceDark;
            } else if ([value isEqual:@"light"]) {
                keyboardAppearance = UIKeyboardAppearanceLight;
            } else {
                continue;
            }

            // Property is not KVC-compliant
            [(UIView<UITextInputTraits> *)view setKeyboardAppearance:keyboardAppearance];

            continue;
        } else if ([key isEqual:@"keyboardType"]) {
            // Translate to keyboard type
            UIKeyboardType keyboardType;
            if ([value isEqual:@"default"]) {
                keyboardType = UIKeyboardTypeDefault;
            } else if ([value isEqual:@"ASCIICapable"]) {
                keyboardType = UIKeyboardTypeASCIICapable;
            } else if ([value isEqual:@"numbersAndPunctuation"]) {
                keyboardType = UIKeyboardTypeNumbersAndPunctuation;
            } else if ([value isEqual:@"URL"]) {
                keyboardType = UIKeyboardTypeURL;
            } else if ([value isEqual:@"numberPad"]) {
                keyboardType = UIKeyboardTypeNumberPad;
            } else if ([value isEqual:@"phonePad"]) {
                keyboardType = UIKeyboardTypePhonePad;
            } else if ([value isEqual:@"namePhonePad"]) {
                keyboardType = UIKeyboardTypeNamePhonePad;
            } else if ([value isEqual:@"emailAddress"]) {
                keyboardType = UIKeyboardTypeEmailAddress;
            } else if ([value isEqual:@"decimalPad"]) {
                keyboardType = UIKeyboardTypeDecimalPad;
            } else if ([value isEqual:@"twitter"]) {
                keyboardType = UIKeyboardTypeTwitter;
            } else if ([value isEqual:@"webSearch"]) {
                keyboardType = UIKeyboardTypeWebSearch;
            } else {
                continue;
            }

            // Property is not KVC-compliant
            [(UIView<UITextInputTraits> *)view setKeyboardType:keyboardType];

            continue;
        } else if ([key isEqual:@"returnKeyType"]) {
            // Translate to return key type
            UIReturnKeyType returnKeyType;
            if ([value isEqual:@"default"]) {
                returnKeyType = UIReturnKeyDefault;
            } else if ([value isEqual:@"go"]) {
                returnKeyType = UIReturnKeyGo;
            } else if ([value isEqual:@"google"]) {
                returnKeyType = UIReturnKeyGoogle;
            } else if ([value isEqual:@"join"]) {
                returnKeyType = UIReturnKeyJoin;
            } else if ([value isEqual:@"next"]) {
                returnKeyType = UIReturnKeyNext;
            } else if ([value isEqual:@"route"]) {
                returnKeyType = UIReturnKeyRoute;
            } else if ([value isEqual:@"search"]) {
                returnKeyType = UIReturnKeySearch;
            } else if ([value isEqual:@"send"]) {
                returnKeyType = UIReturnKeySend;
            } else if ([value isEqual:@"yahoo"]) {
                returnKeyType = UIReturnKeyYahoo;
            } else if ([value isEqual:@"done"]) {
                returnKeyType = UIReturnKeyDone;
            } else if ([value isEqual:@"emergencyCall"]) {
                returnKeyType = UIReturnKeyEmergencyCall;
            } else {
                continue;
            }

            // Property is not KVC-compliant
            [(UIView<UITextInputTraits> *)view setReturnKeyType:returnKeyType];

            continue;
        } else if ([key isEqual:@"datePickerMode"]) {
            UIDatePickerMode datePickerMode;
            if ([value isEqual:@"time"]) {
                datePickerMode = UIDatePickerModeTime;
            } else if ([value isEqual:@"date"]) {
                datePickerMode = UIDatePickerModeDate;
            } else if ([value isEqual:@"dateAndTime"]) {
                datePickerMode = UIDatePickerModeDateAndTime;
            } else if ([value isEqual:@"countDownTimer"]) {
                datePickerMode = UIDatePickerModeCountDownTimer;
            } else {
                continue;
            }

            value = [NSNumber numberWithInt:datePickerMode];
        } else if ([key isEqual:@"activityIndicatorViewStyle"]) {
            UIActivityIndicatorViewStyle activityIndicatorViewStyle;
            if ([value isEqual:@"whiteLarge"]) {
                activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
            } else if ([value isEqual:@"white"]) {
                activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
            } else if ([value isEqual:@"gray"]) {
                activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
            } else {
                continue;
            }

            value = [NSNumber numberWithInt:activityIndicatorViewStyle];
        } else if ([key isEqual:@"separatorStyle"]) {
            UITableViewCellSeparatorStyle tableViewCellSeparatorStyle;
            if ([value isEqual:@"none"]) {
                tableViewCellSeparatorStyle = UITableViewCellSeparatorStyleNone;
            } else if ([value isEqual:@"singleLine"]) {
                tableViewCellSeparatorStyle = UITableViewCellSeparatorStyleSingleLine;
            } else if ([value isEqual:@"singleLineEtched"]) {
                tableViewCellSeparatorStyle = UITableViewCellSeparatorStyleSingleLineEtched;
            } else {
                continue;
            }

            value = [NSNumber numberWithInt:tableViewCellSeparatorStyle];
        } else if ([key isEqual:@"accessoryType"]) {
            // Translate to table view cell accessory type
            UITableViewCellAccessoryType tableViewCellAccessoryType;
            if ([value isEqual:@"none"]) {
                tableViewCellAccessoryType = UITableViewCellAccessoryNone;
            } else if ([value isEqual:@"disclosureIndicator"]) {
                tableViewCellAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
            } else if ([value isEqual:@"detailDisclosureButton"]) {
                tableViewCellAccessoryType = UITableViewCellAccessoryDetailDisclosureButton;
            } else if ([value isEqual:@"checkmark"]) {
                tableViewCellAccessoryType = UITableViewCellAccessoryCheckmark;
            } else if ([value isEqual:@"detailButton"]) {
                tableViewCellAccessoryType = UITableViewCellAccessoryDetailButton;
            } else {
                continue;
            }

            value = [NSNumber numberWithInt:tableViewCellAccessoryType];
        } else if ([key isEqual:@"selectionStyle"]) {
            // Translate to table view cell selection style
            UITableViewCellSelectionStyle tableViewCellSelectionStyle;
            if ([value isEqual:@"none"]) {
                tableViewCellSelectionStyle = UITableViewCellSelectionStyleNone;
            } else if ([value isEqual:@"blue"]) {
                tableViewCellSelectionStyle = UITableViewCellSelectionStyleBlue;
            } else if ([value isEqual:@"gray"]) {
                tableViewCellSelectionStyle = UITableViewCellSelectionStyleGray;
            } else if ([value isEqual:@"default"]) {
                tableViewCellSelectionStyle = UITableViewCellSelectionStyleDefault;
            } else {
                continue;
            }

            value = [NSNumber numberWithInt:tableViewCellSelectionStyle];
        } else if ([key isEqual:@"dataDetectorTypes"]) {
            // Translate to data detector types
            UIDataDetectorTypes dataDetectorTypes;
            if ([value isEqual:@"none"]) {
                dataDetectorTypes = UIDataDetectorTypeNone;
            } else if ([value isEqual:@"all"]) {
                dataDetectorTypes = UIDataDetectorTypeAll;
            } else {
                NSArray *components = [value componentsSeparatedByString:@"|"];

                dataDetectorTypes = 0;

                for (NSString *component in components) {
                    if ([component isEqual:@"phoneNumber"]) {
                        dataDetectorTypes |= UIDataDetectorTypePhoneNumber;
                    } else if ([component isEqual:@"link"]) {
                        dataDetectorTypes |= UIDataDetectorTypeLink;
                    } else if ([component isEqual:@"address"]) {
                        dataDetectorTypes |= UIDataDetectorTypeAddress;
                    } else if ([component isEqual:@"calendarEvent"]) {
                        dataDetectorTypes |= UIDataDetectorTypeCalendarEvent;
                    } else {
                        continue;
                    }
                }
            }

            value = [NSNumber numberWithUnsignedInteger:dataDetectorTypes];
        } else if ([key isEqual:@"paginationBreakingMode"]) {
            // Translate to web pagination breaking mode
            UIWebPaginationBreakingMode webPaginationBreakingMode;
            if ([value isEqual:@"page"]) {
                webPaginationBreakingMode = UIWebPaginationBreakingModePage;
            } else if ([value isEqual:@"column"]) {
                webPaginationBreakingMode = UIWebPaginationBreakingModeColumn;
            } else {
                continue;
            }

            value = [NSNumber numberWithInt:webPaginationBreakingMode];
        } else if ([key isEqual:@"paginationMode"]) {
            // Translate to web pagination mode
            UIWebPaginationMode webPaginationMode;
            if ([value isEqual:@"unpaginated"]) {
                webPaginationMode = UIWebPaginationModeUnpaginated;
            } else if ([value isEqual:@"leftToRight"]) {
                webPaginationMode = UIWebPaginationModeLeftToRight;
            } else if ([value isEqual:@"topToBottom"]) {
                webPaginationMode = UIWebPaginationModeTopToBottom;
            } else if ([value isEqual:@"bottomToTop"]) {
                webPaginationMode = UIWebPaginationModeBottomToTop;
            } else if ([value isEqual:@"rightToLeft"]) {
                webPaginationMode = UIWebPaginationModeRightToLeft;
            } else {
                continue;
            }

            value = [NSNumber numberWithInt:webPaginationMode];
        } else if ([key isEqual:@"barStyle"]) {
            // Translate to bar style
            UIBarStyle barStyle;
            if ([value isEqual:@"default"]) {
                barStyle = UIBarStyleDefault;
            } else if ([value isEqual:@"black"]) {
                barStyle = UIBarStyleBlack;
            } else {
                continue;
            }

            value = [NSNumber numberWithInt:barStyle];
        } else if ([key isEqual:@"searchBarStyle"]) {
            // Translate to search bar style
            UISearchBarStyle searchBarStyle;
            if ([value isEqual:@"default"]) {
                searchBarStyle = UISearchBarStyleDefault;
            } else if ([value isEqual:@"prominent"]) {
                searchBarStyle = UISearchBarStyleProminent;
            } else if ([value isEqual:@"minimal"]) {
                searchBarStyle = UISearchBarStyleMinimal;
            } else {
                continue;
            }

            value = [NSNumber numberWithInt:searchBarStyle];
        } else if ([key isEqual:@"axis"]) {
            // Translate to layout constraint axis
            UILayoutConstraintAxis layoutConstraintAxis;
            if ([value isEqual:@"horizontal"]) {
                layoutConstraintAxis = UILayoutConstraintAxisHorizontal;
            } else if ([value isEqual:@"vertical"]) {
                layoutConstraintAxis = UILayoutConstraintAxisVertical;
            } else {
                continue;
            }

            value = [NSNumber numberWithInt:layoutConstraintAxis];
        } else if ([key isEqual:@"alignment"] && [view isKindOfClass:[UIStackView class]]) {
            // Translate to stack view alignment
            UIStackViewAlignment stackViewAlignment;
            if ([value isEqual:@"fill"]) {
                stackViewAlignment = UIStackViewAlignmentFill;
            } else if ([value isEqual:@"leading"]) {
                stackViewAlignment = UIStackViewAlignmentLeading;
            } else if ([value isEqual:@"top"]) {
                stackViewAlignment = UIStackViewAlignmentTop;
            } else if ([value isEqual:@"firstBaseline"]) {
                stackViewAlignment = UIStackViewAlignmentFirstBaseline;
            } else if ([value isEqual:@"center"]) {
                stackViewAlignment = UIStackViewAlignmentCenter;
            } else if ([value isEqual:@"trailing"]) {
                stackViewAlignment = UIStackViewAlignmentTrailing;
            } else if ([value isEqual:@"bottom"]) {
                stackViewAlignment = UIStackViewAlignmentBottom;
            } else if ([value isEqual:@"lastBaseline"]) {
                stackViewAlignment = UIStackViewAlignmentLastBaseline;
            } else {
                continue;
            }

            value = [NSNumber numberWithInt:stackViewAlignment];
        } else if ([key isEqual:@"distribution"]) {
            // Translate to stack view distribution
            UIStackViewDistribution stackViewDistribution;
            if ([value isEqual:@"fill"]) {
                stackViewDistribution = UIStackViewDistributionFill;
            } else if ([value isEqual:@"fillEqually"]) {
                stackViewDistribution = UIStackViewDistributionFillEqually;
            } else if ([value isEqual:@"fillProportionally"]) {
                stackViewDistribution = UIStackViewDistributionFillProportionally;
            } else if ([value isEqual:@"equalSpacing"]) {
                stackViewDistribution = UIStackViewDistributionEqualSpacing;
            } else if ([value isEqual:@"equalCentering"]) {
                stackViewDistribution = UIStackViewDistributionEqualSpacing;
            } else {
                continue;
            }

            value = [NSNumber numberWithInt:stackViewDistribution];
        } else if ([key rangeOfString:@"[Cc]olor$" options:NSRegularExpressionSearch].location != NSNotFound) {
            // Parse color specification
            UIColor *color;
            if ([value isKindOfClass:[NSString self]]) {
                color = [LMViewBuilder colorValue:value];
            } else {
                color = nil;
            }

            if (color == nil) {
                continue;
            }

            if ([path hasPrefix:@"layer"]) {
                value = (id)[color CGColor];
            } else {
                value = color;
            }
        } else if ([key rangeOfString:@"[Ff]ont$" options:NSRegularExpressionSearch].location != NSNotFound) {
            // Parse font specification
            UIFont *font;
            if ([value isKindOfClass:[NSString self]]) {
                font = [LMViewBuilder fontValue:value];
            } else {
                font = nil;
            }

            if (font == nil) {
                continue;
            }

            value = font;
        } else if ([key rangeOfString:@"[Ii]mage$" options:NSRegularExpressionSearch].location != NSNotFound) {
            // Load named image
            UIImage *image;
            if ([value isKindOfClass:[NSString self]]) {
                image = [UIImage imageNamed:value];
            } else {
                image = nil;
            }

            if (image == nil) {
                continue;
            }

            value = image;
        } else if ([key rangeOfString:@"^(?:horizontal|vertical)Content(?:CompressionResistance|Hugging)Priority$"
            options:NSRegularExpressionSearch].location != NSNotFound) {
            // Translate to layout priority
            UILayoutPriority layoutPriority;
            if ([value isEqual:@"required"]) {
                layoutPriority = UILayoutPriorityRequired;
            } else if ([value isEqual:@"high"]) {
                layoutPriority = UILayoutPriorityDefaultHigh;
            } else if ([value isEqual:@"low"]) {
                layoutPriority = UILayoutPriorityDefaultLow;
            } else {
                layoutPriority = [value floatValue];
            }

            value = [NSNumber numberWithFloat:layoutPriority];
        } else if ([key isEqual:@"layoutMargins"] || [key isEqual:@"contentEdgeInsets"] || [key isEqual:@"textContainerInset"]) {
            // Create edge insets from value
            CGFloat inset = [value floatValue];

            value = [NSValue valueWithUIEdgeInsets:UIEdgeInsetsMake(inset, inset, inset, inset)];
        }

        [view setValue:value forKeyPath:path];
    }
}

- (instancetype)init
{
    return nil;
}

- (instancetype)initWithOwner:(id)owner root:(UIView *)root
{
    self = [super init];

    if (self) {
        _owner = owner;
        _root = root;

        _properties = [NSMutableDictionary new];
        _strings = [NSMutableDictionary new];

        _views = [NSMutableArray new];
    }

    return self;
}

- (UIView *)root
{
    return _root;
}

- (void)parser:(NSXMLParser *)parser foundProcessingInstructionWithTarget:(NSString *)target data:(NSString *)data
{
    if ([_views count] == 0) {
        if ([target isEqual:kPropertiesTarget]) {
            // Load properties
            NSDictionary *properties = nil;

            if ([data hasPrefix:@"{"]) {
                NSError *error = nil;

                properties = [NSJSONSerialization JSONObjectWithData:[data dataUsingEncoding:NSUTF8StringEncoding]
                    options:0 error:&error];

                if (error != nil) {
                    NSDictionary *userInfo = [error userInfo];

                    [NSException raise:NSGenericException format:@"Error reading properties: \"%@\"",
                        [userInfo objectForKey:@"NSDebugDescription"]];
                }
            } else {
                NSString *path = [[NSBundle mainBundle] pathForResource:data ofType:@"plist"];

                if (path != nil) {
                    properties = [NSDictionary dictionaryWithContentsOfFile:path];
                }
            }

            for (NSString *key in properties) {
                NSMutableDictionary *template = (NSMutableDictionary *)[_properties objectForKey:key];

                if (template == nil) {
                    template = [NSMutableDictionary new];

                    [_properties setObject:template forKey:key];
                }

                [template addEntriesFromDictionary:(NSDictionary *)[properties objectForKey:key]];
            }
        } else if ([target isEqual:kStringsTarget]) {
            // Load strings
            NSString *path = [[NSBundle mainBundle] pathForResource:data ofType:@"strings" inDirectory:nil];

            if (path != nil) {
                [_strings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
            }
        }
    } else {
        // Notify view
        id view = [_views lastObject];

        if ([view isKindOfClass:[UIView self]]) {
            [view processMarkupInstruction:target data:data];
        }
    }
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
    namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
    attributes:(NSDictionary *)attributes
{
    NSString *factory = nil;
    NSString *template = nil;
    NSString *outlet = nil;
    NSMutableDictionary *actions = [NSMutableDictionary new];
    NSMutableDictionary *properties = [NSMutableDictionary new];

    for (NSString *key in attributes) {
        NSString *value = [attributes objectForKey:key];

        if ([key isEqual:kFactoryKey]) {
            factory = value;
        } else if ([key isEqual:kTemplateKey]) {
            template = value;
        } else if ([key isEqual:kOutletKey]) {
            outlet = value;
        } else if ([key hasPrefix:kActionPrefix] && [key length] > [kActionPrefix length]
            && ![key isEqual:@"onTintColor"]) {
            [actions setObject:value forKey:key];
        } else {
            if ([value hasPrefix:kLocalizedStringPrefix]) {
                value = [value substringFromIndex:[kLocalizedStringPrefix length]];

                NSString *localizedValue = [_strings objectForKey:value];

                if (localizedValue == nil) {
                    localizedValue = [[NSBundle mainBundle] localizedStringForKey:value value:nil table:nil];
                }

                value = localizedValue;
            }

            [properties setObject:value forKey:key];
        }
    }

    // Determine element type
    Class type;
    if ([_views count] == 0 && [elementName isEqual:kRootTag]) {
        if (_root == nil) {
            [NSException raise:NSGenericException format:@"Root view is not defined."];
        }

        type = [_root class];
    } else {
        type = NSClassFromString(elementName);
    }

    if (type == nil) {
        // Notify view
        if ([_views count] > 0) {
            id view = [_views lastObject];

            if ([view isKindOfClass:[UIView self]]) {
                [view processMarkupElement:elementName properties:properties];
            }
        }

        [_views addObject:[NSNull null]];
    } else {
        // Create view
        UIView *view;
        if ([_views count] == 0 && _root != nil) {
            view = _root;
        } else {
            if (![type isSubclassOfClass:[UIView self]]) {
                [NSException raise:NSGenericException format:@"<%@> is not a valid element type.", elementName];
            }

            if (factory != nil) {
                SEL selector = NSSelectorFromString(factory);
                IMP method = [type methodForSelector:selector];
                id (*function)(id, SEL) = (void *)method;

                view = function(type, selector);
            } else {
                view = [type new];
            }

            if (view == nil) {
                [NSException raise:NSGenericException format:@"Unable to instantiate element <%@>.", elementName];
            }
        }

        // Set outlet value
        if (outlet != nil) {
            [_owner setValue:view forKey:outlet];
        }

        // Apply properties
        if (template != nil) {
            [LMViewBuilder applyPropertyValues:[_properties objectForKey:template] toView:view];
        }

        [LMViewBuilder applyPropertyValues:properties toView:view];

        // Add action handlers
        for (NSString *key in actions) {
            NSString *name = [key substringFromIndex:[kActionPrefix length]];

            UIControlEvents controlEvents;
            if ([name isEqual:@"TouchDown"]) {
                controlEvents = UIControlEventTouchDown;
            } else if ([name isEqual:@"TouchDownRepeat"]) {
                controlEvents = UIControlEventTouchDownRepeat;
            } else if ([name isEqual:@"TouchDragInside"]) {
                controlEvents = UIControlEventTouchDragInside;
            } else if ([name isEqual:@"TouchDragOutside"]) {
                controlEvents = UIControlEventTouchDragOutside;
            } else if ([name isEqual:@"TouchDragEnter"]) {
                controlEvents = UIControlEventTouchDragEnter;
            } else if ([name isEqual:@"TouchDragExit"]) {
                controlEvents = UIControlEventTouchDragExit;
            } else if ([name isEqual:@"TouchUpInside"]) {
                controlEvents = UIControlEventTouchUpInside;
            } else if ([name isEqual:@"TouchUpOutside"]) {
                controlEvents = UIControlEventTouchUpOutside;
            } else if ([name isEqual:@"TouchCancel"]) {
                controlEvents = UIControlEventTouchCancel;
            } else if ([name isEqual:@"ValueChanged"]) {
                controlEvents = UIControlEventValueChanged;
            } else if ([name isEqual:@"EditingDidBegin"]) {
                controlEvents = UIControlEventEditingDidBegin;
            } else if ([name isEqual:@"EditingChanged"]) {
                controlEvents = UIControlEventEditingChanged;
            } else if ([name isEqual:@"EditingDidEnd"]) {
                controlEvents = UIControlEventEditingDidEnd;
            } else if ([name isEqual:@"EditingDidEndOnExit"]) {
                controlEvents = UIControlEventEditingDidEndOnExit;
            } else if ([name isEqual:@"AllTouchEvents"]) {
                controlEvents = UIControlEventAllTouchEvents;
            } else if ([name isEqual:@"AllEditingEvents"]) {
                controlEvents = UIControlEventAllEditingEvents;
            } else if ([name isEqual:@"AllEvents"]) {
                controlEvents = UIControlEventAllEvents;
            } else {
                controlEvents = 0;
            }

            SEL action = NSSelectorFromString([actions objectForKey:key]);
            
            [(UIControl *)view addTarget:_owner action:action forControlEvents:controlEvents];
        }

        // Push onto view stack
        [_views addObject:view];
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
    namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    // Pop from view stack
    id view = [_views lastObject];

    [_views removeLastObject];

    if ([_views count] > 0) {
        // Add to superview
        if ([view isKindOfClass:[UIView self]]) {
            id superview = [_views lastObject];
            
            if ([superview isKindOfClass:[UIView self]]) {
                [superview appendMarkupElementView:view];
            }
        }
    } else {
        // Inject properties and strings into owner
        @try {
            [_owner setValue:_properties forKey:kPropertiesTarget];
            [_owner setValue:_strings forKey:kStringsTarget];
        }
        @catch (NSException *exception) {
            if (![[exception name] isEqual:NSUndefinedKeyException]) {
                @throw exception;
            }
        }

        // Set root view
        if ([view isKindOfClass:[UIView self]]) {
            _root = view;
        }
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)error
{
    NSDictionary *userInfo = [error userInfo];

    [NSException raise:NSGenericException format:@"A parse error occurred at line %d, column %d.",
        [[userInfo objectForKey:@"NSXMLParserErrorLineNumber"] intValue],
        [[userInfo objectForKey:@"NSXMLParserErrorColumn"] intValue]];
}

@end
