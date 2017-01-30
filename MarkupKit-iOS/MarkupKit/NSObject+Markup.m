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

#import "NSObject+Markup.h"

#import <objc/message.h>

@interface LMBinding : NSObject

@property (weak, nonatomic, readonly) id object;
@property (nonatomic, readonly) NSString *property;

@property (weak, nonatomic, readonly) UIView *view;
@property (nonatomic, readonly) NSString *keyPath;

- (instancetype)initWithObject:(id)object property:(NSString *)property view:(UIView *)view keyPath:(NSString *)keyPath;

@end

@implementation NSObject (Markup)

- (void)applyMarkupPropertyValue:(id)value forKey:(NSString *)key
{
    if (value == nil || value == [NSNull null]) {
        return;
    }

    [self setValue:value forKey:key];
}

- (void)applyMarkupPropertyValue:(id)value forKeyPath:(NSString *)keyPath
{
    NSArray *components = [keyPath componentsSeparatedByString:@"."];

    NSUInteger n = [components count];

    id target = self;

    for (NSUInteger i = 0; i < n - 1; i++) {
        target = [target valueForKey:[components objectAtIndex:i]];
    }

    [target applyMarkupPropertyValue:value forKey:[components objectAtIndex:n - 1]];
}

- (void)bind:(NSString *)property toView:(UIView *)view withKeyPath:(NSString *)keyPath
{
    // TODO Create binding
    // TODO Add binding as observer of property on self
    // TODO Add binding as observer of key path on view
    // TODO Add binding to bindings list
}

- (void)unbindAll
{
    // TODO For each binding in bindings list, remove as observer on self and view
    // TODO Clear bindings list
}

@end

@implementation LMBinding
{
    BOOL _update;
}

- (instancetype)initWithObject:(id)object property:(NSString *)property view:(UIView *)view keyPath:(NSString *)keyPath
{
    self = [super init];

    if (self) {
        _object = object;
        _property = property;

        _view = view;
        _keyPath = keyPath;
    }

    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (!_update) {
        _update = YES;

        id value = [change objectForKey:NSKeyValueChangeNewKey];

        if (value != nil && value != [NSNull null]) {
            if (object == _object) {
                [_view setValue:value forKey:_keyPath];
            } else {
                [_object setValue:value forKey:_property];
            }
        }

        _update = NO;
    }
}

@end
