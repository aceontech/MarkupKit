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

#import "LMBoxView.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Box view that arranges subviews vertically in a column.
 */
@interface LMColumnView : LMBoxView

/**
 * Specifies that nested subviews should be vertically aligned.
 */
@property (nonatomic) BOOL alignToGrid;

/**
 * The amount of spacing before the first view.
 */
@property (nonatomic) CGFloat topSpacing;

/**
 * The amount of spacing after the last view.
 */
@property (nonatomic) CGFloat bottomSpacing;

@end

NS_ASSUME_NONNULL_END
