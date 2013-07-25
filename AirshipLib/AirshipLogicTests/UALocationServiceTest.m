/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import <SenTestingKit/SenTestingKit.h>

#import "UAirship.h"
#import "UALocationEvent.h"
#import "UAAnalytics.h"
#import "UALocationCommonValues.h"
#import "UALocationService.h"
#import "UALocationService+Internal.h"
#import "UAStandardLocationProvider.h"
#import "UASignificantChangeProvider.h"
#import "UALocationTestUtils.h"
#import "JRSwizzle.h"
#import "CLLocationManager+Test.h"


// This needs to be kept in sync with the value in UAirship

@interface UALocationService(Test)
+ (BOOL)returnYES;
+ (BOOL)returnNO;
@end

@implementation UALocationService(Test)

+ (BOOL)returnYES {
    return YES;
}
+ (BOOL)returnNO {
    return NO;
}

@end

@interface UALocationServiceTest : SenTestCase {
  @private
    UALocationService *_locationService;
    id _mockLocationService; //[OCMockObject partialMockForObject:locationService]
}
- (void)swizzleCLLocationClassMethod:(SEL)oneSelector withMethod:(SEL)anotherSelector;
- (void)swizzleUALocationServiceClassMethod:(SEL)oneMethod withMethod:(SEL)anotherMethod;
- (void)swizzleCLLocationClassEnabledAndAuthorized;
- (void)swizzleCLLocationClassBackFromEnabledAndAuthorized;
- (void)setTestValuesInNSUserDefaults;
@end


@implementation UALocationServiceTest

#pragma mark -
#pragma mark Setup Teardown

- (void)setUp {

    // Only works on the first pass, values will change when accessed. When fresh values are needed in
    // user defaults call the setTestValuesInNSUserDefaults method

    _locationService = [[UALocationService alloc] initWithPurpose:@"TEST"];
    _mockLocationService = [[OCMockObject partialMockForObject:_locationService] retain];
}

- (void)tearDown {
    RELEASE(_mockLocationService);
    RELEASE(_locationService);
}

#pragma mark -
#pragma mark Basic Object Initialization

- (void)testBasicInit{
    [self setTestValuesInNSUserDefaults];
    UALocationService *testService = [[[UALocationService alloc] init] autorelease];
    STAssertTrue(120.00 == testService.minimumTimeBetweenForegroundUpdates, nil);
    STAssertFalse([UALocationService airshipLocationServiceEnabled], nil);
    STAssertEquals(testService.standardLocationDesiredAccuracy, kCLLocationAccuracyHundredMeters, nil);
    STAssertEquals(testService.standardLocationDistanceFilter, kCLLocationAccuracyHundredMeters, nil);
    STAssertEquals(testService.singleLocationBackgroundIdentifier, UIBackgroundTaskInvalid, nil);
}

- (void)setInitWithPurpose {
    STAssertTrue([_locationService.purpose isEqualToString:@"TEST"], nil);
}

// Register user defaults only works on the first app run. This is also called in UAirship, and may or may
// not have occured at this point. The setting in NSUserDefaults may have been changed, keep this in mind
// when testing the values in user defaults
- (void)setTestValuesInNSUserDefaults {
    // UALocationService defaults. This needs to be kept in sync with the method in UAirship
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setValue:[NSNumber numberWithBool:NO] forKey:UALocationServiceEnabledKey];
    [userDefaults setValue:@"TEST" forKey:UALocationServicePurposeKey];
    //kCLLocationAccuracyHundredMeters works, since it is also a double, this may change in future
    [userDefaults setValue:[NSNumber numberWithDouble:kCLLocationAccuracyHundredMeters] forKey:UAStandardLocationDistanceFilterKey];
    [userDefaults setValue:[NSNumber numberWithDouble:kCLLocationAccuracyHundredMeters] forKey:UAStandardLocationDesiredAccuracyKey];
}

#pragma mark -
#pragma mark Getters and Setters

// don't test the single location purpose, because it's transient and would not be changed once started

- (void)testMinimumTime {
    _locationService.minimumTimeBetweenForegroundUpdates = 42.0;
    STAssertTrue(_locationService.minimumTimeBetweenForegroundUpdates == 42.0, nil);
}
- (void)testSetPurpose {
    _locationService.significantChangeProvider = [UASignificantChangeProvider providerWithDelegate:_locationService];
    NSString *awsm = @"awesomeness";
    _locationService.purpose = awsm;
    STAssertTrue([awsm isEqualToString:_locationService.standardLocationProvider.purpose], nil);
    STAssertTrue([awsm isEqualToString:_locationService.significantChangeProvider.purpose], nil);
    STAssertTrue(awsm == [[NSUserDefaults standardUserDefaults] valueForKey:UALocationServicePurposeKey], nil);
}

- (void)testStandardLocationGetSet {
    _locationService.standardLocationDesiredAccuracy = 10.0;
    _locationService.standardLocationDistanceFilter = 24.0;
    UAStandardLocationProvider *standard = _locationService.standardLocationProvider;
    STAssertTrue(standard.distanceFilter == 24.0, nil);
    STAssertTrue(standard.desiredAccuracy == 10.0, nil);
    STAssertTrue(_locationService.standardLocationDesiredAccuracy == 10.0, nil);
    STAssertTrue(_locationService.standardLocationDistanceFilter == 24.0, nil);
}

- (void)testSignificantChangeGetSet {
    UASignificantChangeProvider *significant = [[[UASignificantChangeProvider alloc] initWithDelegate:nil] autorelease];
    _locationService.significantChangeProvider = significant;
    STAssertEqualObjects(_locationService, _locationService.significantChangeProvider.delegate, nil);
}

- (void)testSingleLocationGetSet {
    _locationService.singleLocationDesiredAccuracy = 42.0;
    _locationService.timeoutForSingleLocationService = 100.0;
    STAssertEquals(42.0, [[NSUserDefaults standardUserDefaults] doubleForKey:UASingleLocationDesiredAccuracyKey], nil);
    STAssertEquals(100.0, [[NSUserDefaults standardUserDefaults] doubleForKey:UASingleLocationTimeoutKey], nil);
    STAssertEquals(42.0, _locationService.singleLocationDesiredAccuracy, nil);
    STAssertEquals(100.0, _locationService.timeoutForSingleLocationService, nil);
}

- (void)testCachedLocation {
    id mockLocation = [OCMockObject niceMockForClass:[CLLocationManager class]];
    _locationService.standardLocationProvider.locationManager = mockLocation;
    [(CLLocationManager *)[mockLocation expect] location];
    [_locationService location];
    [mockLocation verify];
}

#pragma mark NSUserDefaults class method access

- (void)testNSUserDefaultsMethods {
    NSString *cats = @"CATS_EVERYWHERE";
    NSString *catKey = @"Cat";
    [UALocationService setObject:cats forLocationServiceKey:catKey];
    NSString *back = [[NSUserDefaults standardUserDefaults] valueForKey:catKey];
    STAssertTrue([back isEqualToString:cats], nil);

    back = [UALocationService objectForLocationServiceKey:catKey];
    STAssertTrue([back isEqualToString:cats], nil);

    NSString *boolKey = @"I_LIKE_CATS";
    [UALocationService setBool:YES forLocationServiceKey:boolKey];
    BOOL boolBack = [[NSUserDefaults standardUserDefaults] boolForKey:boolKey];
    STAssertTrue(boolBack, nil);
    STAssertTrue([UALocationService boolForLocationServiceKey:boolKey], nil);

    double dbl = 42.0;
    NSString *dblKey = @"test_double_key";
    [UALocationService setDouble:dbl forLocationServiceKey:dblKey];
    STAssertTrue(dbl == [[NSUserDefaults standardUserDefaults] doubleForKey:dblKey], nil);
    STAssertTrue(dbl == [UALocationService doubleForLocationServiceKey:dblKey], nil);

    double answer = 42.0;
    [UALocationService setDouble:answer forLocationServiceKey:UASingleLocationDesiredAccuracyKey];
    [UALocationService setDouble:answer forLocationServiceKey:UAStandardLocationDesiredAccuracyKey];
    [UALocationService setDouble:answer forLocationServiceKey:UAStandardLocationDistanceFilterKey];
    STAssertEquals((CLLocationAccuracy)answer, [_locationService desiredAccuracyForLocationServiceKey:UASingleLocationDesiredAccuracyKey], nil);
    STAssertEquals((CLLocationAccuracy)answer,[_locationService desiredAccuracyForLocationServiceKey:UAStandardLocationDesiredAccuracyKey], nil);
}

#pragma mark Location Setters
- (void)testStandardLocationSetter {
    UAStandardLocationProvider *standard = [[[UAStandardLocationProvider alloc] initWithDelegate:nil] autorelease];
    _locationService.standardLocationProvider = standard;

    STAssertEqualObjects(standard, _locationService.standardLocationProvider, nil);
    STAssertEqualObjects(_locationService.standardLocationProvider.delegate, _locationService, nil);
    STAssertTrue(_locationService.standardLocationDesiredAccuracy == _locationService.standardLocationProvider.desiredAccuracy, nil);
    STAssertTrue(_locationService.standardLocationDistanceFilter == _locationService.standardLocationProvider.distanceFilter, nil);
}

- (void)testSignificantChangeSetter {
    UASignificantChangeProvider *significant = [[[UASignificantChangeProvider alloc] initWithDelegate:nil] autorelease];
    _locationService.significantChangeProvider = significant;

    STAssertEqualObjects(significant, _locationService.significantChangeProvider, nil);
    STAssertEqualObjects(_locationService.significantChangeProvider.delegate, _locationService, nil);
}   
 
#pragma mark -
#pragma mark Starting/Stopping Location Services 

#pragma mark  Standard Location
- (void)testStartReportingLocation {
    [[_mockLocationService expect] startReportingLocationWithProvider:OCMOCK_ANY];
    _locationService.standardLocationProvider = nil;
    [_locationService startReportingStandardLocation];
    STAssertTrue([_locationService.standardLocationProvider isKindOfClass:[UAStandardLocationProvider class]], nil);
    [_mockLocationService verify];
}

- (void)testStopUpdatingLocation {
    UAStandardLocationProvider *standardDelegate = [[[UAStandardLocationProvider alloc] initWithDelegate:_locationService] autorelease];
    _locationService.standardLocationProvider = standardDelegate;
    id mockDelegate = [OCMockObject niceMockForClass:[CLLocationManager class]];
    standardDelegate.locationManager = mockDelegate;
    [[mockDelegate expect] stopUpdatingLocation];
    [_locationService stopReportingStandardLocation];
    [mockDelegate verify];
    STAssertEquals(UALocationProviderNotUpdating, _locationService.standardLocationServiceStatus, @"Service should not be updating");
}

- (void)testStandardLocationDidUpdateToLocation {
    id mockDelegate = [OCMockObject niceMockForProtocol:@protocol(UALocationServiceDelegate)];
    _locationService.delegate = mockDelegate;
    _locationService.standardLocationDesiredAccuracy = 5.0;
    [[mockDelegate reject] locationService:OCMOCK_ANY didUpdateToLocation:OCMOCK_ANY fromLocation:OCMOCK_ANY];
    CLLocation *location = [[[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(54, 34)
                                                         altitude:54 
                                               horizontalAccuracy:20 
                                                 verticalAccuracy:20 
                                                        timestamp:[NSDate date]] autorelease];
    [_locationService standardLocationDidUpdateToLocation:location fromLocation:[UALocationTestUtils testLocationPDX]];
    mockDelegate =  [OCMockObject niceMockForProtocol:@protocol(UALocationServiceDelegate)];
    _locationService.delegate = mockDelegate;
    _locationService.standardLocationDesiredAccuracy = 30.0;
    [[_mockLocationService stub] reportLocationToAnalytics:OCMOCK_ANY fromProvider:OCMOCK_ANY];
    [[mockDelegate expect] locationService:OCMOCK_ANY didUpdateToLocation:location fromLocation:OCMOCK_ANY];
    [_locationService standardLocationDidUpdateToLocation:location fromLocation:[UALocationTestUtils testLocationPDX]];
    [mockDelegate verify];
}

#pragma mark Significant Change Service
- (void)testStartMonitoringSignificantChanges {
    [[_mockLocationService expect] startReportingLocationWithProvider:OCMOCK_ANY];
    [_locationService startReportingSignificantLocationChanges];
    STAssertTrue([_locationService.significantChangeProvider isKindOfClass:[UASignificantChangeProvider class]], nil);
    [_mockLocationService verify];
}

- (void)testStopMonitoringSignificantChanges {
    id mockLocationManager = [OCMockObject niceMockForClass:[CLLocationManager class]];
    UASignificantChangeProvider *sigChangeDelegate = [[[UASignificantChangeProvider alloc] initWithDelegate:_locationService] autorelease];
    _locationService.significantChangeProvider = sigChangeDelegate;
    sigChangeDelegate.locationManager = mockLocationManager;
    [[mockLocationManager expect] stopMonitoringSignificantLocationChanges];
    [_locationService stopReportingSignificantLocationChanges];
    [mockLocationManager verify];
    STAssertEquals(UALocationProviderNotUpdating, _locationService.significantChangeServiceStatus, @"Sig change should not be updating");
}

- (void)testSignificantChangeDidUpdate {
    CLLocation *pdx = [UALocationTestUtils testLocationPDX];
    [[_mockLocationService expect] reportLocationToAnalytics:pdx fromProvider:OCMOCK_ANY];
    [_locationService significantChangeDidUpdateToLocation:pdx fromLocation:[UALocationTestUtils testLocationSFO]];
    [_mockLocationService verify];
}


#pragma mark -
#pragma mark CLLocationManager Authorization

- (void)testCLLocationManagerAuthorization {
    // Check just CoreLocation authorization
    [UALocationService setAirshipLocationServiceEnabled:YES];
    [self swizzleCLLocationClassEnabledAndAuthorized];
    STAssertTrue([UALocationService locationServicesEnabled], nil);
    STAssertTrue([UALocationService locationServiceAuthorized], nil);
    STAssertTrue([_locationService isLocationServiceEnabledAndAuthorized], nil);
    STAssertFalse([UALocationService coreLocationWillPromptUserForPermissionToRun], nil);

    [self swizzleCLLocationClassBackFromEnabledAndAuthorized];
    [self swizzleCLLocationClassMethod:@selector(authorizationStatus) withMethod:@selector(returnCLLocationStatusDenied)];
    STAssertFalse([UALocationService locationServiceAuthorized], nil);
    STAssertFalse([_locationService isLocationServiceEnabledAndAuthorized], nil);
    STAssertTrue([UALocationService coreLocationWillPromptUserForPermissionToRun], nil);

    [self swizzleCLLocationClassMethod:@selector(returnCLLocationStatusDenied) withMethod:@selector(authorizationStatus)];
    [self swizzleCLLocationClassMethod:@selector(locationServicesEnabled) withMethod:@selector(returnNO)];
    STAssertFalse([UALocationService locationServicesEnabled], nil);
    STAssertFalse([_locationService isLocationServiceEnabledAndAuthorized], nil);
    STAssertTrue([UALocationService coreLocationWillPromptUserForPermissionToRun], nil);

    [self swizzleCLLocationClassMethod:@selector(returnNO) withMethod:@selector(locationServicesEnabled)];
    [self swizzleCLLocationClassMethod:@selector(authorizationStatus) withMethod:@selector(returnCLLocationStatusRestricted)];
    STAssertFalse([UALocationService locationServiceAuthorized], nil);
    STAssertFalse([_locationService isLocationServiceEnabledAndAuthorized], nil);
    STAssertTrue([UALocationService coreLocationWillPromptUserForPermissionToRun], nil);

    [self swizzleCLLocationClassMethod:@selector(returnCLLocationStatusRestricted) withMethod:@selector(authorizationStatus)];
    [self swizzleCLLocationClassMethod:@selector(authorizationStatus) withMethod:@selector(returnCLLocationStatusNotDetermined)];
    STAssertTrue([UALocationService locationServiceAuthorized], nil);
    STAssertTrue([_locationService isLocationServiceEnabledAndAuthorized], nil);
    STAssertFalse([UALocationService coreLocationWillPromptUserForPermissionToRun], nil); 

    [self swizzleCLLocationClassMethod:@selector(returnCLLocationStatusNotDetermined) withMethod:@selector(authorizationStatus)];
}

- (void)testAirshipLocationAuthorization {
    [self swizzleCLLocationClassEnabledAndAuthorized];
    [UALocationService setAirshipLocationServiceEnabled:NO];
    STAssertFalse([_locationService isLocationServiceEnabledAndAuthorized], @"This should report NO when airship services are toggled off");

    [UALocationService setAirshipLocationServiceEnabled:YES];
    STAssertTrue([_locationService isLocationServiceEnabledAndAuthorized], nil);

    [self swizzleCLLocationClassBackFromEnabledAndAuthorized];
}

- (void)testForcePromptLocation {
    [[[_mockLocationService expect] andReturnValue:@NO] isLocationServiceEnabledAndAuthorized];
    id mockProvider = [OCMockObject niceMockForClass:[UAStandardLocationProvider class]];
    [[mockProvider expect] startReportingLocation];

    _locationService.promptUserForLocationServices = YES;
    [_locationService startReportingLocationWithProvider:mockProvider];
    [_mockLocationService verify];
    [mockProvider verify];
}

- (void)testLocationTimeoutError {
    _locationService.bestAvailableSingleLocation = [UALocationTestUtils testLocationPDX];
    NSError *locationError = [_locationService locationTimeoutError];
    STAssertTrue([UALocationServiceTimeoutError isEqualToString:locationError.domain], nil);
    STAssertTrue(UALocationServiceTimedOut == locationError.code, nil);
    STAssertEquals(_locationService.bestAvailableSingleLocation, 
                   [[locationError userInfo] objectForKey:UALocationServiceBestAvailableSingleLocationKey ], nil);
}


#pragma mark -
#pragma mark Single Location Service

/* Test the single location provider starts with a given provider, and
 sets the status appropriately. Also tests that the service starts and
 lazy loads a location manager */
- (void)testReportCurrentLocationStarts{
    UAStandardLocationProvider *standard = [[[UAStandardLocationProvider alloc] initWithDelegate:nil] autorelease];
    id mockProvider = [OCMockObject partialMockForObject:standard];
    _locationService.singleLocationProvider = standard;
    STAssertEqualObjects(_locationService, _locationService.singleLocationProvider.delegate, nil);

    // Nil the delegate, it should be reset when the service is started
    _locationService.singleLocationProvider.delegate = nil;
    [[[_mockLocationService expect] andReturnValue:@YES] isLocationServiceEnabledAndAuthorized];
    [[mockProvider expect] startReportingLocation];
    [_locationService reportCurrentLocation];
    STAssertEqualObjects(_locationService, _locationService.singleLocationProvider.delegate, nil);

    [_mockLocationService verify];
    [mockProvider verify];
    
}

- (void)testReportCurrentLocationWontStartUnauthorized {
    _locationService.singleLocationProvider = nil;
    [[[_mockLocationService expect] andReturnValue:@NO] isLocationServiceEnabledAndAuthorized];
    [_locationService reportCurrentLocation];
    [_mockLocationService verify];
    //This depends on the lazy loading working correctly
    STAssertNil(_locationService.singleLocationProvider, nil);
}

/* Tests that the single location service won't start when already updating */
- (void)testAcquireSingleLocationWontStartWhenUpdating {
    // Make sure location services are authorized
    [[[_mockLocationService expect] andReturnValue:@NO] isLocationServiceEnabledAndAuthorized];
    id mockProvider = [OCMockObject niceMockForClass:[UAStandardLocationProvider class]];

    UALocationProviderStatus updating = UALocationProviderUpdating;
    [[[mockProvider stub] andReturnValue:OCMOCK_VALUE(updating)] serviceStatus];

    _locationService.singleLocationProvider = mockProvider;
    [[mockProvider reject] startReportingLocation];
    [_locationService reportCurrentLocation];
}

/* Accuracy calculations */
- (void)testSingleLocationDidUpdateToLocation {
    _locationService.singleLocationDesiredAccuracy = 10.0;
    _locationService.singleLocationProvider = [[[UAStandardLocationProvider alloc] initWithDelegate:_locationService] autorelease];

    id mockDelegate = [OCMockObject niceMockForProtocol:@protocol(UALocationServiceDelegate)];
    _locationService.delegate = mockDelegate;

    // Test that the location service is stopped when a good location is received.
    CLLocation *pdx = [[[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(50, 50) altitude:100.0 horizontalAccuracy:5 verticalAccuracy:5 timestamp:[NSDate date]] autorelease];
    CLLocation *sfo = [UALocationTestUtils testLocationSFO];
    [[mockDelegate expect] locationService:_locationService didUpdateToLocation:pdx fromLocation:sfo];
    [[_mockLocationService expect] stopSingleLocationWithLocation:pdx];
    [_locationService singleLocationDidUpdateToLocation:pdx fromLocation:sfo];
    [mockDelegate verify];

    // Test that location that is not accurate enough does not stop the location service
    pdx = [[[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(50, 50) altitude:100.0 horizontalAccuracy:12.0 verticalAccuracy:5 timestamp:[NSDate date]] autorelease];
    [[_mockLocationService reject] stopSingleLocationWithLocation:OCMOCK_ANY];
    [_locationService singleLocationDidUpdateToLocation:pdx fromLocation:sfo];
    STAssertEquals(pdx, _locationService.bestAvailableSingleLocation, nil);
}

/* Test that the single location service won't start if a valid location has been 
 received in the past 120 seconds. This important for the automatic single location service,
 multitasking, and the fact that the single location service is run as a background task
 */
// Verifies that the service stops after receiving a valid location
// and that an analytics call is made

- (void)testSingleLocationWontStartBeforeMinimumTimeBetweenLocations {
    _locationService.minimumTimeBetweenForegroundUpdates = 500;
    _locationService.dateOfLastLocation = [NSDate date];
    _locationService.automaticLocationOnForegroundEnabled = YES;
    [[_mockLocationService reject] reportCurrentLocation];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
}

// Only test that that the method call is made to start the service
- (void)testSingleLocationStartsOnAppForeground {
    _locationService.minimumTimeBetweenForegroundUpdates = 0;
    _locationService.dateOfLastLocation = [NSDate date];
    _locationService.automaticLocationOnForegroundEnabled = YES;  
    [[_mockLocationService expect] reportCurrentLocation];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
    [_mockLocationService verify]; 
}

// Lightweight tests for method calls only
- (void)testStopSingleLocationWithLocation {
    CLLocation *pdx = [UALocationTestUtils testLocationPDX];
    _locationService.singleLocationProvider = [UAStandardLocationProvider providerWithDelegate:_locationService];
    [[_mockLocationService expect] reportLocationToAnalytics:pdx fromProvider:_locationService.singleLocationProvider];
    [[_mockLocationService expect] stopSingleLocation];
    [_locationService stopSingleLocationWithLocation:pdx];
    [_mockLocationService verify];
}

// Lightweight tests for method calls only
- (void)testStopSingleLocationWithError {
    // Setup comparisions
    id mockLocationDelegate = [OCMockObject mockForProtocol:@protocol(UALocationServiceDelegate)];
    NSError* error = [_locationService locationTimeoutError];
    __block UALocationService* service = nil;
    __block NSError* locationError = nil;
    void (^argBlock)(NSInvocation*) = ^(NSInvocation* invocation) {
        [invocation getArgument:&service atIndex:2];
        [invocation getArgument:&locationError atIndex:3];
    };
    //
    [[[mockLocationDelegate expect] andDo:argBlock] locationService:_locationService didFailWithError:OCMOCK_ANY];
    _locationService.singleLocationProvider = [UAStandardLocationProvider providerWithDelegate:_locationService];
    _locationService.bestAvailableSingleLocation = [UALocationTestUtils testLocationPDX];

    [[mockLocationDelegate expect] locationService:_locationService didUpdateToLocation:_locationService.bestAvailableSingleLocation fromLocation:nil];
    _locationService.delegate = mockLocationDelegate;

    [[_mockLocationService expect] reportLocationToAnalytics:_locationService.bestAvailableSingleLocation fromProvider:_locationService.singleLocationProvider];
    [[_mockLocationService expect] stopSingleLocation];
    [_locationService stopSingleLocationWithError:error];

    STAssertEqualObjects(error, locationError, nil);
    STAssertEqualObjects(service, _locationService, nil);
    STAssertTrue([locationError.domain isEqualToString:UALocationServiceTimeoutError], nil);
    STAssertTrue(_locationService.singleLocationBackgroundIdentifier == UIBackgroundTaskInvalid, @"BackgroundTaskIdentifier in UALocationService needs to be invalid");
}


#pragma mark -
#pragma mark Location Service Provider start/restart BOOLS

- (void)testStartRestartBooleansOnProviders {
    id mockStandard = [OCMockObject niceMockForClass:[UAStandardLocationProvider class]];
    id mockSignificant = [OCMockObject niceMockForClass:[UASignificantChangeProvider class]];

    // Setting this to YES is a quick way to get the startReportingLocationWithProvider: method to
    // allow the location service to be started. 
    _locationService.promptUserForLocationServices = YES;

    _locationService.standardLocationProvider = mockStandard;
    _locationService.significantChangeProvider = mockSignificant;
    [_locationService startReportingStandardLocation];
    STAssertTrue(_locationService.shouldStartReportingStandardLocation, nil);

    [_locationService startReportingSignificantLocationChanges];
    STAssertTrue(_locationService.shouldStartReportingSignificantChange, nil);

    [_locationService stopReportingStandardLocation];
    STAssertFalse(_locationService.shouldStartReportingStandardLocation, nil);

    [_locationService stopReportingSignificantLocationChanges];
    STAssertFalse(_locationService.shouldStartReportingSignificantChange, nil);
}

#pragma mark -
#pragma mark Automatic Location Update on Foreground

- (void)testAutomaticLocationOnForegroundEnabledCallsReportCurrentLocation {
    id mockStandard = [OCMockObject niceMockForClass:[UAStandardLocationProvider class]];
    _locationService.automaticLocationOnForegroundEnabled = NO;
    _locationService.singleLocationProvider = mockStandard;

    [[_mockLocationService expect] reportCurrentLocation];
    _locationService.automaticLocationOnForegroundEnabled = YES;
    [_mockLocationService verify];

    [[_mockLocationService reject] reportCurrentLocation];
    _locationService.automaticLocationOnForegroundEnabled = YES;
}

- (void)testAutomaticLocationUpdateOnForegroundShouldUpdateCases {
    // setting automatic location on foreground has the side effect of
    // calling reportCurrentLocation
    [[_mockLocationService expect] reportCurrentLocation];
    _locationService.automaticLocationOnForegroundEnabled = YES;
    [_mockLocationService verify];

    [[_mockLocationService expect] reportCurrentLocation];
    // Setup a date over 120.0 seconds ago
    NSDate *dateOver120 = [[[NSDate alloc] initWithTimeInterval:-121.0 sinceDate:[NSDate date]] autorelease];
    _locationService.dateOfLastLocation = dateOver120;
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
    [_mockLocationService verify];
}

- (void)testAutomaticLocationOnForegroundShouldNotUpdateCases {
    _locationService.automaticLocationOnForegroundEnabled = NO;
    [[_mockLocationService reject] reportCurrentLocation];

    // If there is another call to acquireSingleLocaitonAndUpload, this will fail
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
    _locationService.dateOfLastLocation = [NSDate date];
    [[_mockLocationService reject] reportCurrentLocation];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]]; 

    UALocationService *localService = [[[UALocationService alloc] initWithPurpose:@"test"] autorelease];
    id localMockService = [OCMockObject partialMockForObject:localService];
    localService.automaticLocationOnForegroundEnabled = YES;

    // setup a date for the current time
    localService.dateOfLastLocation = [NSDate date];
    [[localMockService reject] reportCurrentLocation];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
}

- (void)testShouldPerformAutoLocationUpdate {
    _locationService.automaticLocationOnForegroundEnabled = NO;
    STAssertFalse([_locationService shouldPerformAutoLocationUpdate], nil);

    _locationService.automaticLocationOnForegroundEnabled = YES;
    _locationService.dateOfLastLocation = nil;
    STAssertTrue([_locationService shouldPerformAutoLocationUpdate], nil);

    _locationService.dateOfLastLocation = [NSDate dateWithTimeIntervalSinceNow:-121.0];
    STAssertTrue([_locationService shouldPerformAutoLocationUpdate], nil);

    _locationService.dateOfLastLocation = [NSDate dateWithTimeIntervalSinceNow:-90.0];
    STAssertFalse([_locationService shouldPerformAutoLocationUpdate], nil);
    
}

#pragma mark -
#pragma mark Restarting Location service on startup

- (void)testStopLocationServiceWhenBackgroundNotEnabledAndAppEntersBackground {
    _locationService.backgroundLocationServiceEnabled = NO;

    [[[_mockLocationService expect] andReturnValue:@YES] isLocationServiceEnabledAndAuthorized];
    [[[_mockLocationService expect] andReturnValue:@YES] isLocationServiceEnabledAndAuthorized];

    [_locationService startReportingStandardLocation];
    [_locationService startReportingSignificantLocationChanges];

    [[[_mockLocationService expect] andForwardToRealObject] stopReportingStandardLocation];
    [[[_mockLocationService expect] andForwardToRealObject] stopReportingSignificantLocationChanges];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
    [_mockLocationService verify];
}

- (void)testLocationServicesNotStoppedOnAppBackgroundWhenEnabled {
    _locationService.backgroundLocationServiceEnabled = YES;
    [[_mockLocationService reject] stopReportingStandardLocation];
    [[_mockLocationService reject] stopReportingSignificantLocationChanges];
    [[[_mockLocationService expect] andForwardToRealObject] appDidEnterBackground];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
    [_mockLocationService verify];
    STAssertFalse([UALocationService boolForLocationServiceKey:@"standardLocationServiceStatusRestart"], nil);
    STAssertFalse([UALocationService boolForLocationServiceKey:@"significantChangeServiceStatusRestart"], nil);
}

// If background services are enabled, they do not need to be restarted on foreground events
- (void)testLocationServicesNotStartedWhenBackgroundServicesEnabled {
    _locationService.backgroundLocationServiceEnabled = YES;
    [[_mockLocationService reject] startReportingStandardLocation];
    [[_mockLocationService reject] startReportingSignificantLocationChanges];
    [[[_mockLocationService expect] andForwardToRealObject] appWillEnterForeground];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
    [_mockLocationService verify];
    
}

// When background location services are not enabled, they need to be restarted on app foreground
- (void)testStartLocationServiceOnAppForegroundWhenBackgroundServicesNotEnabled {
    // location services can't be started without authorization, and since objects are lazy loaded
    // skip starting and just add them manually. 
    _locationService.standardLocationProvider = [UAStandardLocationProvider providerWithDelegate:_locationService];
    _locationService.significantChangeProvider = [UASignificantChangeProvider providerWithDelegate:_locationService];

    // Setup booleans as if location services were started previously
    _locationService.shouldStartReportingStandardLocation = YES;
    _locationService.shouldStartReportingSignificantChange = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];

    // Setup proper expectations for app foreground
    [[[_mockLocationService expect] andForwardToRealObject] startReportingStandardLocation];
    [[[_mockLocationService expect] andForwardToRealObject] startReportingSignificantLocationChanges];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
    [_mockLocationService verify];

    // Check that distanceFilter and desiredAccuracy match whatever is in NSUserDefaults at this point
    CLLocationAccuracy accuracy = [[NSUserDefaults standardUserDefaults] doubleForKey:UAStandardLocationDesiredAccuracyKey];
    CLLocationDistance distance = [[NSUserDefaults standardUserDefaults] doubleForKey:UAStandardLocationDistanceFilterKey];

    // The location values returned by the UALocationService come directly off the CLLocationManager object
    STAssertEquals(accuracy, _locationService.standardLocationDesiredAccuracy, nil);
    STAssertEquals(distance, _locationService.standardLocationDistanceFilter, nil);
}

// When services arent running, and backround is not enabled, restart values are set to NO
- (void)testBackgroundServiceValuesAreFalse {
    _locationService.backgroundLocationServiceEnabled = NO;
    _locationService.standardLocationProvider.serviceStatus = UALocationProviderNotUpdating;
    _locationService.significantChangeProvider = [UASignificantChangeProvider providerWithDelegate:_locationService];
    _locationService.significantChangeProvider.serviceStatus = UALocationProviderNotUpdating;

    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
    STAssertFalse(_locationService.shouldStartReportingStandardLocation , nil);
    STAssertFalse(_locationService.shouldStartReportingSignificantChange , nil);

    [[_mockLocationService reject] startReportingStandardLocation];
    [[_mockLocationService reject] startReportingSignificantLocationChanges];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];

    [_mockLocationService verify];
}

#pragma mark -
#pragma mark UALocationProvider Delegate callbacks

- (void)testDidFailWithErrorAndDidChangeAuthorization {
    id mockDelegate = [OCMockObject mockForProtocol:@protocol(UALocationServiceDelegate)];
    _locationService.delegate = mockDelegate;
    UAStandardLocationProvider *standard = [UAStandardLocationProvider providerWithDelegate:_locationService];
    _locationService.standardLocationProvider = standard;

    [[mockDelegate expect] locationService:_locationService didChangeAuthorizationStatus:kCLAuthorizationStatusDenied];
    [standard.delegate locationProvider:standard withLocationManager:standard.locationManager didChangeAuthorizationStatus:kCLAuthorizationStatusDenied];
    [mockDelegate verify];

    NSError *locationError = [NSError errorWithDomain:kCLErrorDomain code:kCLErrorDenied userInfo:nil];
    [[mockDelegate expect] locationService:_locationService didFailWithError:locationError];
    [standard.delegate locationProvider:standard withLocationManager:standard.locationManager didFailWithError:locationError];
    [mockDelegate verify];

    NSError *error = [NSError errorWithDomain:kCLErrorDomain code:kCLErrorNetwork userInfo:nil];
    [[mockDelegate expect] locationService:_locationService didFailWithError:error];
    [standard.delegate locationProvider:standard withLocationManager:standard.locationManager didFailWithError:error];
    [mockDelegate verify];
    STAssertFalse([[NSUserDefaults standardUserDefaults] boolForKey:UADeprecatedLocationAuthorizationKey], @"deprecated key should return NO");
}

- (void)testUpdateToNewLocation {
    CLLocation *pdx = [UALocationTestUtils testLocationPDX];
    CLLocation *sfo = [UALocationTestUtils testLocationSFO];
    _locationService.significantChangeProvider = [[[UASignificantChangeProvider alloc] initWithDelegate:_locationService] autorelease];
    _locationService.singleLocationProvider = [[[UAStandardLocationProvider alloc] initWithDelegate:_locationService] autorelease];

    [[_mockLocationService expect] singleLocationDidUpdateToLocation:pdx fromLocation:sfo];
    [[_mockLocationService expect] standardLocationDidUpdateToLocation:pdx fromLocation:sfo];
    [[_mockLocationService expect] significantChangeDidUpdateToLocation:pdx fromLocation:sfo];

    [_locationService.standardLocationProvider.delegate locationProvider:_locationService.standardLocationProvider 
                                                    withLocationManager:_locationService.standardLocationProvider.locationManager 
                                                      didUpdateLocation:pdx 
                                                           fromLocation:sfo];
    [_locationService.singleLocationProvider.delegate locationProvider:_locationService.singleLocationProvider 
                                                  withLocationManager:_locationService.singleLocationProvider.locationManager 
                                                    didUpdateLocation:pdx 
                                                         fromLocation:sfo];
    [_locationService.significantChangeProvider.delegate locationProvider:_locationService.significantChangeProvider 
                                                     withLocationManager:_locationService.significantChangeProvider.locationManager 
                                                       didUpdateLocation:pdx 
                                                            fromLocation:sfo];
    [_mockLocationService verify];
}

#pragma mark -
#pragma mark Support Methods -> Swizzling

// Don't forget to unswizzle the swizzles in cases of strange behavior
- (void)swizzleCLLocationClassMethod:(SEL)oneSelector withMethod:(SEL)anotherSelector {
    NSError *swizzleError = nil;
    [CLLocationManager jr_swizzleClassMethod:oneSelector withClassMethod:anotherSelector error:&swizzleError];
    STAssertNil(swizzleError, @"Method swizzling for CLLocationManager failed with error %@", swizzleError.description);
}
- (void)swizzleUALocationServiceClassMethod:(SEL)oneMethod withMethod:(SEL)anotherMethod {
    NSError *swizzleError = nil;
    [UALocationService jr_swizzleClassMethod:oneMethod withClassMethod:anotherMethod error:&swizzleError];
    STAssertNil(swizzleError,@"Method swizzling for UALocationService failed with error %@", swizzleError.description);
}

- (void)swizzleCLLocationClassEnabledAndAuthorized {
    NSError *locationServicesSizzleError = nil;
    NSError *authorizationStatusSwizzleError = nil;

    [self swizzleCLLocationClassMethod:@selector(locationServicesEnabled) withMethod:@selector(returnYES)];
    [self swizzleCLLocationClassMethod:@selector(authorizationStatus) withMethod:@selector(returnCLLocationStatusAuthorized)];

    STAssertNil(locationServicesSizzleError, @"Error swizzling locationServicesCall on CLLocation error %@", locationServicesSizzleError.description);
    STAssertNil(authorizationStatusSwizzleError, @"Error swizzling authorizationStatus on CLLocation error %@", authorizationStatusSwizzleError.description);
    STAssertTrue([CLLocationManager locationServicesEnabled], @"This should be swizzled to YES");
    STAssertEquals(kCLAuthorizationStatusAuthorized, [CLLocationManager authorizationStatus], @"this should be kCLAuthorizationStatusAuthorized" );
}

- (void)swizzleCLLocationClassBackFromEnabledAndAuthorized {
    NSError *locationServicesSizzleError = nil;
    NSError *authorizationStatusSwizzleError = nil;

    [self swizzleCLLocationClassMethod:@selector(returnCLLocationStatusAuthorized) withMethod:@selector(authorizationStatus)];
    [self swizzleCLLocationClassMethod:@selector(returnYES) withMethod:@selector(locationServicesEnabled)];

    STAssertNil(locationServicesSizzleError, @"Error unsizzling locationServicesCall on CLLocation error %@", locationServicesSizzleError.description);
    STAssertNil(authorizationStatusSwizzleError, @"Error unswizzling authorizationStatus on CLLocation error %@", authorizationStatusSwizzleError.description);
}

#pragma mark -
#pragma mark Deprecated Location Methods


- (void)testdeprecatedLocationAuthorization {
    STAssertFalse([UALocationService useDeprecatedMethods], nil);

    [self swizzleUALocationServiceClassMethod:@selector(useDeprecatedMethods) withMethod:@selector(returnYES)];
    // The above swizzle should force code execution throgh the deprecated methods.
    STAssertEquals([UALocationService locationServicesEnabled],
                   [CLLocationManager locationServicesEnabled],
                   @"This should call the class and instance method of CLLocationManager, should be equal");

    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:UADeprecatedLocationAuthorizationKey];
    STAssertTrue([UALocationService locationServiceAuthorized], @"This should be YES, it's read out of NSUserDefaults");

    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:UADeprecatedLocationAuthorizationKey];
    STAssertFalse([UALocationService locationServiceAuthorized], @"Thir should report NO, read out of NSUserDefaults");

    // On first run of the app, this key should be nil, and we want a value of authorized for that since the user 
    // has not been asked about location
    [[NSUserDefaults standardUserDefaults] setObject:nil forKey:UADeprecatedLocationAuthorizationKey];
    STAssertTrue([UALocationService locationServiceAuthorized], nil);
    [self swizzleUALocationServiceClassMethod:@selector(returnYES) withMethod:@selector(useDeprecatedMethods)];
}

@end
