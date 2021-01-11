//
//  main.m
//  TransLit
//
//  Created by tim lindner on 10/31/20.
//  Copyright © 2020 tim lindner. All rights reserved.
//

#import <Foundation/Foundation.h>

void output( NSString *out );
void out(NSString *format, ... );
NSString *trim( NSString *s);

void out(NSString *format, ... )
{
    va_list arguments;
    va_start(arguments, format);
    NSString *string = [[NSString alloc] initWithFormat:format arguments:arguments];
    output(string);
}

void output( NSString *out )
{
    NSFileHandle *fh = [NSFileHandle fileHandleWithStandardOutput];
    [fh writeData:[out dataUsingEncoding:NSUTF8StringEncoding]];
}

NSString *trim( NSString *s )
{
    NSRange rangeOfLastWantedCharacter = [s rangeOfCharacterFromSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet] options:NSBackwardsSearch];
    if (rangeOfLastWantedCharacter.location == NSNotFound) {
        return @"";
    }
    
    return [s substringToIndex:rangeOfLastWantedCharacter.location+1]; // non-inclusive
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSError *err;
        NSArray *a;
        NSString *s;
        NSRange r;
        
        if (argc != 3) {
            NSLog( @"%s: <source file> <translation file>\n", argv[0]);
            return -1;
        }
        
        NSString *sourceFile = [NSString stringWithFormat:@"%s", argv[1]];
        NSString *translationFile = [NSString stringWithFormat:@"%s", argv[2]];
        
        NSString *sourceText = [NSString stringWithContentsOfFile:sourceFile encoding:NSUTF8StringEncoding error:&err];
        
        if (err) {
            NSLog(@"%@", err );
            return -1;
        }
        
        NSString *translatioText = [NSString stringWithContentsOfFile:translationFile encoding:NSUTF8StringEncoding error:&err];
 
        if (err) {
            NSLog(@"%@", err );
            return -1;
        }

        NSArray *source = [sourceText componentsSeparatedByString:@"\n"];
        NSMutableArray *outputArray = [NSMutableArray array];
        NSMutableArray *labelArray = [NSMutableArray array];
        NSMutableArray *trapArray = [NSMutableArray array];
        NSMutableArray *fcbArray = [NSMutableArray array];
        NSArray *translation = [translatioText componentsSeparatedByString:@"\n"];
        NSString *startTraps = nil;
        
        NSMutableArray *regex = [NSMutableArray array];

        for (NSString *trans in translation) {
            
            if ([trans isEqualToString:@""]) {
                continue;
            }
            
            if ([trans hasPrefix:@"#"]) {
                continue;
            }
            
            a = [trans componentsSeparatedByString:@"\t"];
            if ([trans hasPrefix:@"0"]) {
                out(@"%@\n", a[1]);
            }
            else if ([trans hasPrefix:@"1"]) {
                NSRegularExpression *rex = [NSRegularExpression regularExpressionWithPattern:a[1] options:NSRegularExpressionCaseInsensitive error:&err];
                
                if (err) {
                    NSLog(@"%@", err );
                    return -1;
                }
                
                if ([a count] < 4) {
                    [regex addObject:@[rex, a[2], @0]];
                } else {
                    [regex addObject:@[rex, a[2], [NSNumber numberWithInteger:[a[3] intValue]]]];
                }
            } else if ([trans hasPrefix:@"2"]) {
                // Also do 2 codes, FCBs
                unsigned start_address = 0;
                unsigned end_address = 0;
                
                [[NSScanner scannerWithString:a[1]] scanHexInt:&start_address];
                [[NSScanner scannerWithString:a[2]] scanHexInt:&end_address];
                
                [fcbArray addObject:@[[NSNumber numberWithUnsignedInteger:start_address], [NSNumber numberWithUnsignedInteger:end_address]]];
            } else if ([trans hasPrefix:@"3"]) {
                startTraps = a[1];
            } else if ([trans isEqualToString:@""]) {
                // do nothing
            } else {
                NSLog( @"unknown command\n");
                return -1;
            }
        }
  
        /* match source lines with regular expressions */
        for (NSString *srcLine in source) {
            
            if ([srcLine isEqualToString:@""]) {
                [outputArray addObject:@""];
                continue;
            }
            
            if ([srcLine hasPrefix:@";"]) {
                [outputArray addObject:srcLine];
                continue;
            }
            
            if ([srcLine hasPrefix:@"XXXX"]) {
                [outputArray addObject:srcLine];
                continue;
            }
            
            /* extract mnemonics and operands, omit leading bytes and trailing comments. Then trim white space */
            s = [srcLine substringFromIndex:18];
            a = [s componentsSeparatedByString:@";"];
            NSString *srcProcessed = trim(a[0]);
            
            bool regex_found = false;
            for (NSArray *regExSet in regex) {
                r = NSMakeRange(0, [srcProcessed length]);
                a = [regExSet[0] matchesInString:srcProcessed options:0 range:r];
                if( [a count] > 0 ) {
                    s = [regExSet[0] stringByReplacingMatchesInString:srcProcessed options:0 range:r withTemplate:regExSet[1]];
                    [outputArray addObject:s];
                    regex_found = true;
                    
                    if( [regExSet[2] integerValue] > 0) {
                        /* capture group represents a label */
                        NSTextCheckingResult *match = a[0];
                        NSRange matchRange = [match rangeAtIndex:[regExSet[2] integerValue]];
                        [labelArray addObject:[srcProcessed substringWithRange:matchRange]];
                    }
                    
                    break;
               }
            }
            
            if (!regex_found) {
                /* if we get here, there was no match */
                [outputArray addObject:[NSNull null]];
            }
        }
        
        /* process trap labels */
        if (startTraps) {
            unsigned current_address = 0;
            [[NSScanner scannerWithString:startTraps] scanHexInt:&current_address];
            int current_trap = 23;
            
            for (NSString *srcLine in source) {
                if ([srcLine hasPrefix:startTraps]) {
                    s = [NSString stringWithFormat:@"%@%@", [srcLine substringWithRange:NSMakeRange(6, 2)], [srcLine substringWithRange:NSMakeRange(9, 2)]];
                    
                    if (current_trap == 3) {
                        [trapArray addObject:@[s, @"INT3"]];
                    }
                    else if (current_trap == 2) {
                        [trapArray addObject:@[s, @"INT2"]];
                    }
                    else if (current_trap == 1) {
                        [trapArray addObject:@[s, @"INT1"]];
                    }
                    else if (current_trap == 0) {
                        [trapArray addObject:@[s, @"RESET"]];
                    } else {
                        [trapArray addObject:@[s, [NSString stringWithFormat:@"TRAP_%d", current_trap]]];
                    }
                    
                    current_trap--;
                    
                    if (current_trap < 0) {
                        break;
                    }
                    
                    current_address += 2;
                    startTraps = [NSString stringWithFormat:@"%4.4X", current_address];
                }
            }
        }
        
        /* Output transliterated source */
        int i=0;
        
        for (NSString *srcLine in source) {
            bool fcb_flag = false;
            if ([srcLine length] > 3) {
                NSString *label = [srcLine substringToIndex:4];
                
                /* check if in a FCB block */
                unsigned address = 0;
                [[NSScanner scannerWithString:label] scanHexInt:&address];
                
                
                for (NSArray *fcb_range in fcbArray) {
                    unsigned start_address = [fcb_range[0] unsignedIntValue];
                    unsigned end_address = [fcb_range[1] unsignedIntValue];
                    
                    if (address >= start_address && address <=end_address) {
                        fcb_flag = true;
//                        if (address == start_address ) {
//                            out(@"    org $%@\n", label);
//                        }
                        
                        if ([labelArray containsObject:label]) {
                            out(@"L%@\n", label );
                        }
                        output(@"    fcb " );
                        
                        for (int j=6; j<18; j+=3) {
                            NSString *byte = [srcLine substringWithRange:NSMakeRange(j, 2)];
                            
                            if( [byte isEqualToString:@"  "]) {
                                break;
                            }
                            
                            if (j>6) {
                                output( @"," );
                            }
                            
                            out(@"$%@", byte);
                        }
                        
                        output(@"\n");
                        break;
                    }
                }
            }
            
            if (fcb_flag == false) {
                id object = [outputArray objectAtIndex:i];
            
                if ([object isKindOfClass:[NSNull class]]) {
                    out( @"***** %@\n", srcLine);
                }
                else if ([object isKindOfClass:[NSString class]])
                {
                    s = object;
                    
                    if ([s isEqualToString:@""]) {
                        output( @"\n" );
                    }
                    else if ([s hasPrefix:@";"]) {
                        out( @"%@\n", s );
                    }
                    else if ([s hasPrefix:@"XXXX: "]) {
                        out( @"%@\n", [s substringFromIndex:6]);
                    } else {
                        NSString *label = [srcLine substringToIndex:4];
                        
                        a = [s componentsSeparatedByString:@"\\n"];
                        
                        // check if we need a trap label
                        for (NSArray *trap in trapArray) {
                            if ([trap[0] isEqualToString:label]) {
                                out( @"%@\n", trap[1] );
                                break;
                            }
                        }
                        
                        // check if we need a regular label
                        if ([labelArray containsObject:label]) {
                            out(@"L%@\n", label );
                        }
                        
                        int spaces = 20 - (int)[a[0] length];
                        
                        out( @"    %@%*s%@\n", a[0], spaces, " ", srcLine );
                        
                        for (int j=1; j < [a count]; j++) {
                            out( @"    %@\n", a[j]);
                        }
                    }
                 }
            }
            
            i++;
        }
    }
    return 0;
}

