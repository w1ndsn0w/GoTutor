#import "KataGoWrapper.h"
#import <TargetConditionals.h>
#include <string>
#include <vector>
#include <thread>
#include <unistd.h>

#if !TARGET_OS_SIMULATOR
namespace MainCmds {
    int analysis(const std::vector<std::string>& args);
}
#endif

@implementation KataGoWrapper {
    int in_pipe[2];
    int out_pipe[2];
}

// 【新增】单例模式：整个 App 周期内只生成一个实例
+ (instancetype)shared {
    static KataGoWrapper *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (NSString *)setEngineWithModel:(NSString *)modelPath config:(NSString *)configPath {
    // 【防撞车锁】：如果引擎已经启动了，直接返回成功，绝对不再动管道！
    static BOOL isEngineStarted = NO;
    if (isEngineStarted) return @"引擎已在后台运行中...";
    isEngineStarted = YES;
    
    std::string cppModel = [modelPath UTF8String];
    std::string cppConfig = [configPath UTF8String];
    
    if (cppModel.empty() || cppConfig.empty()) return @"路径为空！";
    
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    chdir([docPath UTF8String]);
    
    pipe(in_pipe);
    pipe(out_pipe);
    
    dup2(in_pipe[0], STDIN_FILENO);
    dup2(out_pipe[1], STDOUT_FILENO);
    
    std::vector<std::string> args = {
        "katago",
        "-model", cppModel,
        "-config", cppConfig
    };
    
#if TARGET_OS_SIMULATOR
    return @"[UI预览模式] 已屏蔽底层 C++ 引擎。";
#else
    std::thread([args]() {
        MainCmds::analysis(args);
    }).detach();
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        char buffer[4096];
        std::string leftOver = "";
        
        while (true) {
            ssize_t count = read(self->out_pipe[0], buffer, sizeof(buffer) - 1);
            if (count > 0) {
                buffer[count] = '\0';
                leftOver += buffer;
                
                size_t pos;
                while ((pos = leftOver.find('\n')) != std::string::npos) {
                    std::string line = leftOver.substr(0, pos);
                    leftOver = leftOver.substr(pos + 1);
                    
                    if (!line.empty()) {
                        NSString *msg = [NSString stringWithUTF8String:line.c_str()];
                        // 【核心修改】：不再单线联系，而是用通知中心向整个 App 广播收到的 JSON！
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter] postNotificationName:@"KataGoJSONBroadcast" object:nil userInfo:@{@"json": msg}];
                        });
                    }
                }
            }
        }
    });
    
    return @"JSON Analysis 引擎初始化中...";
#endif
}

- (void)sendQuery:(NSString *)jsonQuery {
#if !TARGET_OS_SIMULATOR
    NSString *cmdWithNewline = [jsonQuery stringByAppendingString:@"\n"];
    write(in_pipe[1], [cmdWithNewline UTF8String], [cmdWithNewline lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
#endif
}

@end
