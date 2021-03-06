//
//  OutputLanguageWriterJava.m
//  JSONModeler
//
//  Created by Jon Rexeisen on 1/19/12.
//  Copyright (c) 2012 Nerdery Interactive Labs. All rights reserved.
//

#import "OutputLanguageWriterJava.h"
#import "ClassBaseObject.h"
#import "ClassPropertiesObject.h"
#import "NSString+Nerdery.h"

@interface OutputLanguageWriterJava ()

- (NSString *) Java_ImplementationFileForClassObject:(ClassBaseObject *)classObject;

@end

@implementation OutputLanguageWriterJava
//@synthesize classObject = _classObject;

#pragma mark - File Writing Methods

- (BOOL)writeClassObjects:(NSDictionary *)classObjectsDict toURL:(NSURL *)url options:(NSDictionary *)options generatedError:(BOOL *)generatedErrorFlag
{
    BOOL filesHaveHadError = NO;
    BOOL filesHaveBeenWritten = NO;
    
    NSArray *files = [classObjectsDict allValues];
    
    /* Determine package name */
    NSString *packageName;
    if (nil != options[kJavaWritingOptionPackageName]) {
        packageName = options[kJavaWritingOptionPackageName];
    }
    else {
        /* Default value */
        packageName = @"com.MYCOMPANY.MYPROJECT.model";
    }
    
    for(ClassBaseObject *base in files) {
        // This section is to guard against people going through and renaming the class
        // to something that has already been named.
        // This will check the class name and keep appending an additional number until something has been found
        if([[base className] isEqualToString:@"InternalBaseClass"]) {
            NSString *newBaseClassName;
            if (nil != options[kJavaWritingOptionBaseClassName]) {
                newBaseClassName = options[kJavaWritingOptionBaseClassName];
            }
            else {
                newBaseClassName = @"BaseClass";
            }
            BOOL hasUniqueFileNameBeenFound = NO;
            NSUInteger classCheckInteger = 2;
            while (hasUniqueFileNameBeenFound == NO) {
                hasUniqueFileNameBeenFound = YES;
                for(ClassBaseObject *collisionBaseObject in files) {
                    if([[collisionBaseObject className] isEqualToString:newBaseClassName]) {
                        hasUniqueFileNameBeenFound = NO; 
                    }
                }
                if(hasUniqueFileNameBeenFound == NO) {
                    newBaseClassName = [NSString stringWithFormat:@"%@%li", newBaseClassName, classCheckInteger];
                    classCheckInteger++;
                }
            }
            
            [base setClassName:newBaseClassName];
        }
        
        /* Write the .java file to disk */
        NSError *error;
        NSString *outputString = [self Java_ImplementationFileForClassObject:base];
        NSString *filename = [NSString stringWithFormat:@"%@.java", base.className];
        
        /* Define the package name in each file */
        outputString = [outputString stringByReplacingOccurrencesOfString:@"{PACKAGENAME}" withString:packageName];
#ifndef COMMAND_LINE
        [outputString writeToURL:[url URLByAppendingPathComponent:filename]
                     atomically:YES
                       encoding:NSUTF8StringEncoding 
                          error:&error];
#else
        [outputString writeToFile:[[url URLByAppendingPathComponent:filename] absoluteString]
                      atomically:YES
                        encoding:NSUTF8StringEncoding
                           error:&error];
#endif
        if(error) {
            DLog(@"%@", [error localizedDescription]);
            filesHaveHadError = YES;
        } else {
            filesHaveBeenWritten = YES;
        }
    }
    
    /* Return the error flag (by reference) */
    *generatedErrorFlag = filesHaveHadError;
    
    
    return filesHaveBeenWritten;
}

- (NSDictionary *) getOutputFilesForClassObject:(ClassBaseObject *)classObject
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    dict[[NSString stringWithFormat:@"%@.java", classObject.className]] = [self Java_ImplementationFileForClassObject:classObject];
    
    return [NSDictionary dictionaryWithDictionary:dict];
    
}

- (NSString *) Java_ImplementationFileForClassObject:(ClassBaseObject *)classObject
{
#ifndef COMMAND_LINE
    NSBundle *mainBundle = [NSBundle mainBundle];
    
    NSString *interfaceTemplate = [mainBundle pathForResource:@"JavaTemplate" ofType:@"txt"];
    NSString *templateString = [[NSString alloc] initWithContentsOfFile:interfaceTemplate encoding:NSUTF8StringEncoding error:nil];
#else
    NSString *templateString = @"package {PACKAGENAME};\n\nimport org.json.*;\n{IMPORTBLOCK}\n\npublic class {CLASSNAME} {\n	\n    {PROPERTIES}\n    \n	public {CLASSNAME} () {\n		\n	}	\n        \n    public {CLASSNAME} (JSONObject json) {\n    \n{SETTERS}\n    }\n    \n{GETTER_SETTER_METHODS}\n    \n}\n";
#endif
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{CLASSNAME}" withString:classObject.className];
    
    // Flag if class has an ArrayList type property (used for generating the import block)
    BOOL containsArrayList = NO;
    
    // Public Properties
    NSString *propertiesString = @"";
    for(ClassPropertiesObject *property in [classObject.properties allValues]) {
        
        propertiesString = [propertiesString stringByAppendingString:[self propertyForProperty:property]];
        if (property.type == PropertyTypeArray) {
            containsArrayList = YES;
        }
    }
    
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{PROPERTIES}" withString:propertiesString];
    
    // Import Block
    if (containsArrayList) {
        templateString = [templateString stringByReplacingOccurrencesOfString:@"{IMPORTBLOCK}" withString:@"import java.util.ArrayList;"];
    }
    else {
        templateString = [templateString stringByReplacingOccurrencesOfString:@"{IMPORTBLOCK}" withString:@""];
    }
    
    // Constructor arguments
//    NSString *constructorArgs = @"";
//    for (ClassPropertiesObject *property in [classObject.properties allValues]) {
//        //Append a comma if not the first argument added to the string
//        if ( ![constructorArgs isEqualToString:@""] ) {
//            constructorArgs = [constructorArgs stringByAppendingString:@", "];
//        }
//        
//        constructorArgs = [constructorArgs stringByAppendingString:[NSString stringWithFormat:@"%@ %@", [self typeStringForProperty:property], property.name]];
//    }
//    
//    templateString = [templateString stringByReplacingOccurrencesOfString:@"{CONSTRUCTOR_ARGS}" withString:constructorArgs];
    
    
    // Setters strings   
    NSString *settersString = @"";
    for(ClassPropertiesObject *property in [classObject.properties allValues]) {
        NSString *setterForProperty = [self setterForProperty:property];
        settersString = [settersString stringByAppendingString:setterForProperty];
    }
    
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{SETTERS}" withString:settersString];    
    
    NSString *rawObject = @"rawObject";
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{OBJECTNAME}" withString:rawObject];
    
    
    // Getter/Setter Methods
    NSString *getterSetterMethodsString = @"";
    for (ClassPropertiesObject *property in [classObject.properties allValues]) {
        getterSetterMethodsString = [getterSetterMethodsString stringByAppendingString:[self getterForProperty:property]];
        getterSetterMethodsString = [getterSetterMethodsString stringByAppendingString:[self setterMethodForProperty:property]];
    }
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{GETTER_SETTER_METHODS}" withString:getterSetterMethodsString];
    
    return templateString;
}

#pragma mark - Reserved Words Callbacks

- (NSSet *)reservedWords
{
    return [NSSet setWithObjects:@"abstract", @"assert", @"boolean", @"break", @"byte", @"case", @"catch", @"char", @"class", @"const", @"continue", @"default", @"do", @"double", @"else", @"enum", @"extends", @"false", @"final", @"finally", @"float", @"for", @"goto", @"if", @"implements", @"import", @"instanceof", @"int", @"interface", @"long", @"native", @"new", @"null", @"package", @"private", @"protected", @"public", @"return", @"short", @"static", @"strictfp", @"super", @"switch", @"synchronized", @"this", @"throw", @"throws", @"transient", @"true", @"try", @"void", @"volatile", @"while", nil];
}

- (NSString *)classNameForObject:(ClassBaseObject *)classObject fromReservedWord:(NSString *)reservedWord
{
    NSString *className = [[reservedWord stringByAppendingString:@"Class"] capitalizeFirstCharacter];
    NSRange startsWithNumeral = [[className substringToIndex:1] rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789"]];
    if ( !(startsWithNumeral.location == NSNotFound && startsWithNumeral.length == 0) ) {
        className = [@"Num" stringByAppendingString:className];
    }
    
    NSMutableArray *components = [[className componentsSeparatedByString:@"_"] mutableCopy];
    
    NSInteger numComponents = [components count];
    for (int i = 0; i < numComponents; ++i) {
        components[i] = [(NSString *)components[i] capitalizeFirstCharacter];
    }
    return [components componentsJoinedByString:@""];
}

- (NSString *)propertyNameForObject:(ClassPropertiesObject *)propertyObject inClass:(ClassBaseObject *)classObject fromReservedWord:(NSString *)reservedWord
{
    /* General case */
    NSString *propertyName = [[reservedWord stringByAppendingString:@"Property"] uncapitalizeFirstCharacter];
    NSRange startsWithNumeral = [[propertyName substringToIndex:1] rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789"]];
    if ( !(startsWithNumeral.location == NSNotFound && startsWithNumeral.length == 0) ) {
        propertyName = [@"num" stringByAppendingString:propertyName];
    }
    return [propertyName uncapitalizeFirstCharacter];
}

#pragma mark - Property Writing Methods

- (NSString *)propertyForProperty:(ClassPropertiesObject *) property
{
    NSString *returnString = [NSString stringWithFormat:@"private %@ %@;\n    ", [self typeStringForProperty:property], property.name];
    
    return returnString;
}

- (NSString *)setterForProperty:(ClassPropertiesObject *)  property
{
    NSString *setterString = @"";
    if(property.isClass && (property.type == PropertyTypeDictionary || property.type == PropertyTypeClass)) {
        setterString = [setterString stringByAppendingFormat:@"        this.%@ = new %@(json.optJSONObject(\"%@\"));\n", property.name, property.referenceClass.className, property.jsonName];
    } else if(property.type == PropertyTypeArray) {
        NSBundle *mainBundle = [NSBundle mainBundle];
        
        if (nil != property.referenceClass) {
#ifndef COMMAND_LINE
            NSString *arrayTemplate = [mainBundle pathForResource:@"JavaArrayTemplate" ofType:@"txt"];
            NSString *templateString = [[NSString alloc] initWithContentsOfFile:arrayTemplate encoding:NSUTF8StringEncoding error:nil];
#else
            NSString *templateString = @"\n        this.{PROPERTYNAME} = new ArrayList<{CLASSNAME}>();\n        JSONArray array{CLASSNAME} = json.optJSONArray(\"{JSONNAME}\");\n        if (null != array{CLASSNAME}) {\n            int {PROPERTYNAME}Length = array{CLASSNAME}.length();\n            for (int i = 0; i < {PROPERTYNAME}Length; i++) {\n                {OBJECTTYPE} item = array{CLASSNAME}.opt{OBJECTTYPE}(i);\n                if (null != item) {\n                    this.{PROPERTYNAME}.add(new {CLASSNAME}(item));\n                }\n            }\n        }\n        else {\n            {OBJECTTYPE} item = json.opt{OBJECTTYPE}(\"{JSONNAME}\");\n            if (null != item) {\n                this.{PROPERTYNAME}.add(new {CLASSNAME}(item));\n            }\n        }\n\n";
#endif
            templateString = [templateString stringByReplacingOccurrencesOfString:@"{JSONNAME}" withString:property.jsonName];
            templateString = [templateString stringByReplacingOccurrencesOfString:@"{PROPERTYNAME}" withString:property.name];
            templateString = [templateString stringByReplacingOccurrencesOfString:@"{CLASSNAME}" withString:property.referenceClass.className];
            setterString = [templateString stringByReplacingOccurrencesOfString:@"{OBJECTTYPE}" withString:@"JSONObject"];
        }
        else {
#ifndef COMMAND_LINE
            NSString *arrayTemplate = [mainBundle pathForResource:@"JavaPrimitiveArrayTemplate" ofType:@"txt"];
            NSString *templateString = [[NSString alloc] initWithContentsOfFile:arrayTemplate encoding:NSUTF8StringEncoding error:nil];
#else
            NSString *templateString = @"\n        this.{PROPERTYNAME} = new ArrayList<{TYPE}>();\n        JSONArray array{CLASSNAME} = json.optJSONArray(\"{JSONNAME}\");\n        if (null != array{CLASSNAME}) {\n            int {PROPERTYNAME}Length = array{CLASSNAME}.length();\n            for (int i = 0; i < {PROPERTYNAME}Length; i++) {\n                {TYPE} item = array{CLASSNAME}.opt{TYPE_UPPERCASE}(i);\n                if (null != item) {\n                    this.{PROPERTYNAME}.add(item);\n                }\n            }\n        }\n        else {\n            {TYPE} item = json.opt{TYPE_UPPERCASE}(\"{JSONNAME}\");\n            if (null != item) {\n                this.{PROPERTYNAME}.add(item);\n            }\n        }\n\n";
#endif
            templateString = [templateString stringByReplacingOccurrencesOfString:@"{JSONNAME}" withString:property.jsonName];
            templateString = [templateString stringByReplacingOccurrencesOfString:@"{PROPERTYNAME}" withString:property.name];
            templateString = [templateString stringByReplacingOccurrencesOfString:@"{CLASSNAME}" withString:[property.name capitalizeFirstCharacter]];
            
            PropertyType type = property.collectionType;
            if (type == PropertyTypeString) {
                templateString = [templateString stringByReplacingOccurrencesOfString:@"{TYPE}" withString:@"String"];
                templateString = [templateString stringByReplacingOccurrencesOfString:@"{TYPE_UPPERCASE}" withString:@"String"];
            }
            else if (type == PropertyTypeInt) {
                templateString = [templateString stringByReplacingOccurrencesOfString:@"{TYPE}" withString:@"int"];
                templateString = [templateString stringByReplacingOccurrencesOfString:@"{TYPE_UPPERCASE}" withString:@"Int"];
            }
            else if (type == PropertyTypeDouble) {
                templateString = [templateString stringByReplacingOccurrencesOfString:@"{TYPE}" withString:@"double"];
                templateString = [templateString stringByReplacingOccurrencesOfString:@"{TYPE_UPPERCASE}" withString:@"Double"];
            }
            else if (type == PropertyTypeBool) {
                templateString = [templateString stringByReplacingOccurrencesOfString:@"{TYPE}" withString:@"boolean"];
                templateString = [templateString stringByReplacingOccurrencesOfString:@"{TYPE_UPPERCASE}" withString:@"Boolean"];
            }
            else {
                templateString = [templateString stringByReplacingOccurrencesOfString:@"{TYPE}" withString:@"JSONObject"];
                templateString = [templateString stringByReplacingOccurrencesOfString:@"{TYPE_UPPERCASE}" withString:@""];
            }
            setterString = [NSString stringWithString:templateString];
        }
        
    } else {
        setterString = [setterString stringByAppendingString:[NSString stringWithFormat:@"        this.%@ = ", property.name]];
        if([property type] == PropertyTypeInt) {
            setterString = [setterString stringByAppendingFormat:@"json.optInt(\"%@\");\n", property.jsonName];
        } else if([property type] == PropertyTypeDouble) {
            setterString = [setterString stringByAppendingFormat:@"json.optDouble(\"%@\");\n", property.jsonName]; 
        } else if([property type] == PropertyTypeBool) {
            setterString = [setterString stringByAppendingFormat:@"json.optBoolean(\"%@\");\n", property.jsonName]; 
        } else if([property type] == PropertyTypeString) {
            setterString = [setterString stringByAppendingFormat:@"json.optString(\"%@\");\n", property.jsonName]; 
        } else {
            setterString = [setterString stringByAppendingFormat:@"json.opt(\"%@\");\n", property.jsonName];
        }
    }
    
    if (!setterString) {
        setterString = @"";
    }
    
    return setterString;
}

- (NSString *)getterForProperty:(ClassPropertiesObject *) property
{
    NSString *getterMethod = [NSString stringWithFormat:@"    public %@ get%@() {\n        return this.%@;\n    }\n\n", [self typeStringForProperty:property], [property.name capitalizeFirstCharacter], property.name];
    return getterMethod;
}

- (NSArray *)setterReferenceClassesForProperty:(ClassPropertiesObject *)  property
{
    return @[];
}

- (NSString *)typeStringForProperty:(ClassPropertiesObject *)  property
{
    switch (property.type) {
        case PropertyTypeString:
            return @"String";
            break;
        case PropertyTypeArray: {
            
            //Special case, switch over the collection type
            switch (property.collectionType) {
                case PropertyTypeClass:
                    return [NSString stringWithFormat:@"ArrayList<%@>", property.collectionTypeString];
                    break;
                case PropertyTypeString:
                    return @"ArrayList<String>";
                    break;
                case PropertyTypeInt:
                    return @"ArrayList<int>";
                    break;
                case PropertyTypeBool:
                    return @"ArrayList<boolean>";
                    break;
                case PropertyTypeDouble:
                    return @"ArrayList<double>";
                    break;
                default:
                    break;
            }
            
            break;
        }
        case PropertyTypeDictionary:
            return @"Dictionary";
            break;
        case PropertyTypeInt:
            return @"int";
            break;
        case PropertyTypeBool:
            return @"boolean";
            break;
        case PropertyTypeDouble:
            return @"double";
            break;
        case PropertyTypeClass:
            return property.referenceClass.className;
            break;
        case PropertyTypeOther:
            return property.otherType;
            break;
            
        default:
            break;
    }
    return @"";
}

#pragma mark - Java specific implementation details

- (NSString *)setterMethodForProperty:(ClassPropertiesObject *)  property
{
    NSString *setterMethod = [NSString stringWithFormat:@"    public void set%@(%@ %@) {\n        this.%@ = %@;\n    }\n\n", [property.name capitalizeFirstCharacter], [self typeStringForProperty:property], property.name, property.name, property.name];
    return setterMethod;
}



@end
