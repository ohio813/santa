/// Copyright 2015 Google Inc. All rights reserved.
///
/// Licensed under the Apache License, Version 2.0 (the "License");
/// you may not use this file except in compliance with the License.
/// You may obtain a copy of the License at
///
///    http://www.apache.org/licenses/LICENSE-2.0
///
///    Unless required by applicable law or agreed to in writing, software
///    distributed under the License is distributed on an "AS IS" BASIS,
///    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
///    See the License for the specific language governing permissions and
///    limitations under the License.

#import "SNTCommandController.h"

#import "SNTXPCConnection.h"
#import "SNTXPCControlInterface.h"

@implementation SNTCommandController

/// A dictionary to hold all of the available commands.
/// Key is the name of the command
/// Value is the Class
static NSMutableDictionary *registeredCommands;

+ (void)registerCommand:(Class<SNTCommand>)command named:(NSString *)name {
  if (!registeredCommands) {
    registeredCommands = [NSMutableDictionary dictionary];
  }
  registeredCommands[name] = command;
}

+ (NSString *)usage {
  NSMutableString *helpText = [[NSMutableString alloc] init];

  int longestCommandName = 0;
  for (NSString *cmdName in registeredCommands) {
    if ((int)[cmdName length] > longestCommandName) {
      longestCommandName = (int)[cmdName length];
    }
  }

  for (NSString *cmdName in
       [[registeredCommands allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]) {
    Class<SNTCommand> cmd = registeredCommands[cmdName];
    [helpText appendFormat:@"\t%*s - %@\n", longestCommandName,
                           [cmdName UTF8String], [cmd shortHelpText]];
  }

  [helpText appendFormat:@"\nSee 'santactl help <command>' to read about a specific subcommand."];
  return helpText;
}

+ (NSString *)helpForCommandWithName:(NSString *)commandName {
  Class<SNTCommand> command = registeredCommands[commandName];
  if (command) {
    NSString *longHelp = [command longHelpText];
    if (longHelp) {
      return [NSString stringWithFormat:@"Help for '%@':\n%@", commandName, longHelp];
    } else {
      return @"This command does not have any help information.";
    }
  }
  return nil;
}

+ (SNTXPCConnection *)connectToDaemon {
  SNTXPCConnection *daemonConn = [SNTXPCControlInterface configuredConnection];

  daemonConn.invalidationHandler = ^{
    printf("An error occurred communicating with the daemon, is it running?\n");
    exit(1);
  };

  [daemonConn resume];
  return daemonConn;
}

+ (BOOL)hasCommandWithName:(NSString *)commandName {
  return ([registeredCommands objectForKey:commandName] != nil);
}

+ (void)runCommandWithName:(NSString *)commandName arguments:(NSArray *)arguments {
  Class<SNTCommand> command = registeredCommands[commandName];

  if ([command requiresRoot] && getuid() != 0) {
    printf("The command '%s' requires root privileges.\n", [commandName UTF8String]);
    exit(2);
  }

  SNTXPCConnection *daemonConn;
  if ([command requiresDaemonConn]) {
    daemonConn = [self connectToDaemon];
  }

  [command runWithArguments:arguments daemonConnection:daemonConn];

  // The command is responsible for quitting.
  [[NSRunLoop mainRunLoop] run];
}

@end
