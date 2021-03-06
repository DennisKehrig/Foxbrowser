//
//  SGViewController.m
//  SGTabs
//
//  Created by simon on 07.06.12.
//
//
//  Copyright (c) 2012 Simon Grätzer
//  


#import "SGWebViewController.h"
#import "UIViewController+TabsController.h"
#import "UIWebView+WebViewAdditions.h"
#import "SGTabsViewController.h"
#import "SGAppDelegate.h"
#import "Reachability.h"
#import "WeaveService.h"
#import "NSURL+IFUnicodeURL.h"
#import "SGCredentialsPrompt.h"

@interface SGWebViewController ()
@property (strong, nonatomic) NSDictionary *selected;
@property (strong, atomic) SGCredentialsPrompt *credentialsPrompt;
@end

@implementation SGWebViewController {
    int _dialogResult;
}

// TODO Allow to change this preferences in the Settings App
+ (void)load {
    // Enable cookies
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage
                                          sharedHTTPCookieStorage];
    [cookieStorage setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    
    NSString* path = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    path = [path stringByAppendingPathComponent:@"WebCache"];
    NSURLCache *cache = [[NSURLCache alloc] initWithMemoryCapacity:1024*1024*5
                                                      diskCapacity:1024*1024*30
                                                          diskPath:path];
    [NSURLCache setSharedURLCache:cache];
}

- (void)loadView {
    self.webView = [[UIWebView alloc] initWithFrame:CGRectZero];
    self.view = self.webView;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationIsLandscape(interfaceOrientation);
    } else {
        return YES;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"org.graetzer.httpauth"]) {
        [SGHTTPURLProtocol registerProtocol];
    }
        
    self.webView.frame = self.view.bounds;
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
    UILongPressGestureRecognizer *gr = [[UILongPressGestureRecognizer alloc] 
                                        initWithTarget:self action:@selector(handleLongPress:)];
    [self.webView addGestureRecognizer:gr];
    gr.delegate = self;
    self.webView.delegate = self;
    self.webView.scalesPageToFit = YES;
}

- (void)willMoveToParentViewController:(UIViewController *)parent {
    if (!parent) {// View is removed
        [self.webView stopLoading];
        self.webView.delegate = nil;
        [self.webView removeGestureRecognizer:[self.webView.gestureRecognizers lastObject]];
    }
}

- (void)viewWillUnload {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"org.graetzer.httpauth"]) {
        [SGHTTPURLProtocol unregisterProtocol];
    }
    
    [self.webView stopLoading];
    self.webView.delegate = nil;
    [self.webView removeGestureRecognizer:[self.webView.gestureRecognizers lastObject]];
    [super viewWillUnload];
}

- (void)viewDidUnload
{
    [self setWebView:nil];
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated {
    if (!self.webView.request) {
        [self openURL:nil];
    }
}

#pragma mark - UILongPressGesture
- (IBAction)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        CGPoint at = [sender locationInView:self.webView];
        CGPoint pt = at;
        
        // convert point from view to HTML coordinate system
        //CGPoint offset  = [self.webView scrollOffset];
        CGSize viewSize = [self.webView frame].size;
        CGSize windowSize = [self.webView windowSize];
        
        CGFloat f = windowSize.width / viewSize.width;
        pt.x = pt.x * f ;//+ offset.x;
        pt.y = pt.y * f ;//+ offset.y;
        
        [self contextMenuFor:pt showAt:at];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

#pragma mark - Contextual menu

- (void)contextMenuFor:(CGPoint)pt showAt:(CGPoint) at{    
    UIActionSheet *sheet;
    self.selected = [self.webView tagsForPosition:pt];
    
    NSString *link = [self.selected objectForKey:@"A"];
    NSString *imageSrc = [self.selected objectForKey:@"IMG"];
    
    if (link && imageSrc) {
        sheet = [[UIActionSheet alloc] initWithTitle:link
                                            delegate:self 
                                   cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                              destructiveButtonTitle:nil 
                                   otherButtonTitles:
                 NSLocalizedString(@"Open", @"Open a link"),
                 NSLocalizedString(@"Open in a new Tab", nil),
                 NSLocalizedString(@"Save Picture", nil),
                 NSLocalizedString(@"Copy URL", nil), nil];
    } else if (link) {
        sheet = [[UIActionSheet alloc] initWithTitle:link
                                            delegate:self 
                                   cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                              destructiveButtonTitle:nil 
                                   otherButtonTitles:
                 NSLocalizedString(@"Open", @"Open a link"),
                 NSLocalizedString(@"Open in a new Tab", nil), 
                 NSLocalizedString(@"Copy URL", nil), nil];
    } else if (imageSrc) {
        sheet = [[UIActionSheet alloc] initWithTitle:imageSrc
                                            delegate:self 
                                   cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                              destructiveButtonTitle:nil 
                                   otherButtonTitles:
                 NSLocalizedString(@"Save Picture", nil), 
                 NSLocalizedString(@"Copy URL", nil), nil];

    }
    
    if (sheet)
        [sheet showFromRect:CGRectMake(at.x, at.y, 2.5, 2.5) inView:self.webView animated:YES];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    NSString *link = [self.selected objectForKey:@"A"];
    NSString *imageSrc = [self.selected objectForKey:@"IMG"];
    
    if (link && imageSrc) {
        if (buttonIndex == 0) {
            NSURL *url = [NSURL URLWithString:link];
            [self openURL:url];
        } else if (buttonIndex == 1) {
            [self.tabsViewController addTabWithURL:[NSURL URLWithString:link] withTitle:link];
        } else if (buttonIndex == 2) {
            [self performSelectorInBackground:@selector(saveImageURL:) withObject:[NSURL URLWithString:imageSrc]];
        } else if (buttonIndex == 3) {
            [UIPasteboard generalPasteboard].string = link;
        }
    } else if (link) {
        if (buttonIndex == 0) {
            NSURL *url = [NSURL URLWithString:link];
            [self openURL:url];
        } else if (buttonIndex == 1) {
            [self.tabsViewController addTabWithURL:[NSURL URLWithString:link] withTitle:link];
        } else if (buttonIndex == 2) {
            [UIPasteboard generalPasteboard].string = link;
        }
    } else if (imageSrc) {
        if (buttonIndex == 0) {
            [self performSelectorInBackground:@selector(saveImageURL:) withObject:[NSURL URLWithString:imageSrc]];
        } else if (buttonIndex == 1) {
            [UIPasteboard generalPasteboard].string = imageSrc;
        }
    }
}

- (void)saveImageURL:(NSURL *)url {
    @autoreleasepool {
        NSData *data = [NSData dataWithContentsOfURL:url];
        if (data) {
            UIImage *img = [UIImage imageWithData:data];
            UIImageWriteToSavedPhotosAlbum(img, self,
                                           @selector(image:didFinishSavingWithError:contextInfo:), nil);
        }
    }
}

- (void)               image: (UIImage *) image
    didFinishSavingWithError: (NSError *) error
                 contextInfo: (void *) contextInfo {
    if (error) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
                                   message:NSLocalizedString(@"Error Retrieving Data", nil)
                                  delegate:nil
                         cancelButtonTitle:NSLocalizedString(@"OK", nil)
                          otherButtonTitles:nil] show];
    }
}

#pragma mark - UIWebViewDelegate

-  (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    if ([request.URL.scheme isEqualToString:@"newtab"]) {
        NSString *urlString = [[request.URL resourceSpecifier] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSURL *url = [NSURL URLWithString:urlString relativeToURL:self.location];
        [self.tabsViewController addTabWithURL:url withTitle:url.absoluteString];
        return NO;
    }
    
    [SGHTTPURLProtocol setAuthDelegate:self forRequest:request];
    
    if (navigationType != UIWebViewNavigationTypeOther) {
        self.location = request.URL;
        [self.tabsViewController updateChrome];
        
        WeaveOperations *op = [WeaveOperations sharedOperations];
        [op modifyRequest:request];
        return [op handleURLInternal:request.URL];
    }
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    self.loading = YES;
    [self.tabsViewController updateChrome];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    self.loading = NO;
    [webView loadJSTools];
    [webView disableContextMenu];
    [webView modifyLinkTargets];
    [webView modifyOpen];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"org.graetzer.track"]) {
        [webView enableDoNotTrack];
    }
    self.title = [webView title];
    
    NSString *webLoc = [self.webView location];
    if (webLoc.length) {
        self.location = [NSURL URLWithUnicodeString:webLoc];
    }
    
    [self.tabsViewController updateChrome];
    
    // Private mode
    //if (![[NSUserDefaults standardUserDefaults] boolForKey:kWeavePrivateMode]) {
        [[WeaveOperations sharedOperations] addHistoryURL:self.location title:self.title];
    //}
    
    // Do the screenshot if needed
    NSString *path = [UIWebView pathForURL:self.location];
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:path]) {
        NSDictionary *attr = [fm attributesOfItemAtPath:path error:NULL];
        NSDate *modDate = [attr objectForKey:NSFileModificationDate];
        NSNumber *size = [attr objectForKey:NSFileSize];
        if ([modDate compare:[NSDate dateWithTimeIntervalSinceNow:-60*60*24*3]] == NSOrderedAscending || [size longLongValue] == 0) {
            [self.webView performSelector:@selector(saveScreenTo:) withObject:path afterDelay:1.5];
        }
    }
}

//there are too many spurious warnings, so I'm going to just ignore or log them all for now.
- (void)webView:(UIWebView *)theWebView didFailLoadWithError:(NSError *)error
{
    self.loading = NO;
    [self.tabsViewController updateChrome];
    
    NSLog(@"Error code: %d", error.code);
    //ignore these
    if (error.code == NSURLErrorCancelled || [error.domain isEqualToString:@"WebKitErrorDomain"]) return;
    
    if ([error.domain isEqualToString:@"NSURLErrorDomain"])
    {
        DLog(@"Webview error code: %i", error.code);
        // Host not found, try adding www. in front?
        if (error.code == -1003 && [self.location.host rangeOfString:@"www"].location == NSNotFound) {
            NSMutableString *url = [self.location.absoluteString mutableCopy];
            NSRange range = [url rangeOfString:@"://"];
            if (range.location != NSNotFound) {
                [url insertString:@"www." atIndex:range.location+range.length];
                [self openURL:[NSURL URLWithString:url]];
                return;
            }
        }
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error Loading Page", @"error loading page")
                                                        message:[error localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"ok") otherButtonTitles: nil];
        [alert show];
        return;
    }
}

#pragma mark - HTTP Authentication

- (void)URLProtocol:(NSURLProtocol *)protocol didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if (!self.credentialsPrompt) {
        // The protocol states you shall execute the response on the same thread.
        // So show the prompt on the main thread and wait until the result is finished
        dispatch_sync(dispatch_get_main_queue(), ^{
            _dialogResult = -1;
            self.credentialsPrompt = [[SGCredentialsPrompt alloc] initWithChallenge:challenge delegate:self];
            [self.credentialsPrompt show];
        });
        
        NSDate* LoopUntil = [NSDate dateWithTimeIntervalSinceNow:0.5];
        while ((_dialogResult==-1) && ([[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode beforeDate:LoopUntil]))
            LoopUntil = [NSDate dateWithTimeIntervalSinceNow:0.5];
        
//        dispatch_sync(dispatch_get_main_queue(), ^{
//            NSDate* LoopUntil = [NSDate dateWithTimeIntervalSinceNow:0.5];
//            while ((_dialogResult==-1) && ([[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode beforeDate:LoopUntil]))
//                LoopUntil = [NSDate dateWithTimeIntervalSinceNow:0.5];
//        });
        
        SGCredentialsPrompt *creds = self.credentialsPrompt;
        if (_dialogResult == 1) {
            NSURLCredential *credential = [NSURLCredential credentialWithUser:creds.usernameField.text
                                                                     password:creds.passwordField.text
                                                                  persistence:creds.persistence];
            [[NSURLCredentialStorage sharedCredentialStorage] setDefaultCredential:credential
                                                         forProtectionSpace:creds.challenge.protectionSpace];
            [creds.challenge.sender useCredential:credential
                       forAuthenticationChallenge:creds.challenge];
        } else {
            DLog(@"Cancel authenctication");
            [creds.challenge.sender
             cancelAuthenticationChallenge:creds.challenge];
        }
        self.credentialsPrompt = nil;
    } else {
        DLog(@"Called while showing other credential");
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    _dialogResult = buttonIndex;
}


#pragma mark - Networking
 
- (void)openURL:(NSURL *)url {
    if (url) {
        self.location = url;
    }
    if (![self isViewLoaded]) {
        return;
    }
   
    if (![appDelegate canConnectToInternet]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
                                                        message:NSLocalizedString(@"No connection aviable", nil)
                                                       delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil];
        [alert show];
    } else {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.location
                                           cachePolicy:NSURLRequestReloadRevalidatingCacheData
                                       timeoutInterval:10.];
        [[WeaveOperations sharedOperations] modifyRequest:request];
        [self.webView loadRequest:request];
    }
}

- (void)reload {
    [self openURL:nil];
}

@end
