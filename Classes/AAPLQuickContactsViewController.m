/*
    Copyright (C) 2014 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    
                Demonstrates how to use ABPeoplePickerNavigationControllerDelegate, ABPersonViewControllerDelegate, ABNewPersonViewControllerDelegate, and ABUnknownPersonViewControllerDelegate. Shows how to browse a list of Address Book contacts, display and edit a contact record, create a new contact record, and update a partial contact record.
            
*/

#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>
#import "AAPLQuickContactsViewController.h"


typedef NS_ENUM (NSInteger, AAPLActionType)
{
    AAPLActionTypePickContact = 0,
    AAPLActionTypeCreateNewContact,
    AAPLActionTypeDisplayContact,
    AAPLActionTypeEditUnknownContact
};

// Height for the Edit Unknown Contact row
#define kUIEditUnknownContactRowHeight 81.0


@interface AAPLQuickContactsViewController () < ABPeoplePickerNavigationControllerDelegate,ABPersonViewControllerDelegate,
ABNewPersonViewControllerDelegate, ABUnknownPersonViewControllerDelegate>

@property (nonatomic, assign) ABAddressBookRef addressBook;
@property (nonatomic, strong) NSMutableArray *menuArray;

@end


@implementation AAPLQuickContactsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        self.title = @"QuickContacts";
    }
    return self;
}

#pragma mark Load views
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.menuArray = [[NSMutableArray alloc] initWithCapacity:0];
    
    // Create an address book object
    _addressBook = ABAddressBookCreateWithOptions(NULL, NULL);
    [self checkAddressBookAccess];
}

#pragma mark -
#pragma mark Address Book Access
// Check the authorization status of our application for Address Book
-(void)checkAddressBookAccess
{
    switch (ABAddressBookGetAuthorizationStatus())
    {
            // Update our UI if the user has granted access to their Contacts
        case kABAuthorizationStatusAuthorized:
            [self accessGrantedForAddressBook];
            break;
            
            // Prompt the user for access to Contacts if there is no definitive answer
        case kABAuthorizationStatusNotDetermined :
            [self requestAddressBookAccess];
            break;
            
            // Display a message if the user has denied or restricted access to Contacts
        case kABAuthorizationStatusDenied:
        case kABAuthorizationStatusRestricted:
        {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Privacy Warning"
                                                                           message:@"Permission was not granted for Contacts."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
            break;
            
        default:
            break;
    }
}

// Prompt the user for access to their Address Book data
-(void)requestAddressBookAccess
{
    AAPLQuickContactsViewController * __weak weakSelf = self;
    
    ABAddressBookRequestAccessWithCompletion(self.addressBook, ^(bool granted, CFErrorRef error)
                                             {
                                                 if (granted)
                                                 {
                                                     dispatch_async(dispatch_get_main_queue(), ^{
                                                         [weakSelf accessGrantedForAddressBook];
                                                     });
                                                 }
                                             });
}

// This method is called when the user has granted access to their address book data.
-(void)accessGrantedForAddressBook
{
    // Load data from the plist file
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"Menu" ofType:@"plist"];
    self.menuArray = [NSMutableArray arrayWithContentsOfFile:plistPath];
    [self.tableView reloadData];
}

#pragma mark Table view methods
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self.menuArray count];
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *aCell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (aCell == nil)
    {
        // Make the Display Picker and Create New Contact rows look like buttons
        if (indexPath.section < 2)
        {
            aCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            aCell.textLabel.textAlignment = NSTextAlignmentCenter;
        }
        else
        {
            aCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
            aCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            aCell.detailTextLabel.numberOfLines = 0;
            // Display descriptions for the Edit Unknown Contact and Display and Edit Contact rows
            aCell.detailTextLabel.text = [self.menuArray[indexPath.section] valueForKey:@"description"];
        }
    }
    
    aCell.textLabel.text = [self.menuArray[indexPath.section] valueForKey:@"title"];
    return aCell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section)
    {
        case AAPLActionTypePickContact:
            [self showPeoplePickerController];
            break;
        case AAPLActionTypeCreateNewContact:
            [self showNewPersonViewController];
            break;
        case AAPLActionTypeDisplayContact:
            [self showPersonViewController];
            break;
        case AAPLActionTypeEditUnknownContact:
            [self showUnknownPersonViewController];
            break;
        default:
            [self showPeoplePickerController];
            break;
    }
}

#pragma mark TableViewDelegate method
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Change the height if Edit Unknown Contact is the row selected
    return (indexPath.section == AAPLActionTypeEditUnknownContact) ? kUIEditUnknownContactRowHeight : tableView.rowHeight;
}

#pragma mark Show all contacts
// Called when users tap "Display Picker" in the application. Displays a list of contacts and allows users to select a contact from that list.
// The application only shows the phone, email, and birthdate information of the selected contact.
-(void)showPeoplePickerController
{
    ABPeoplePickerNavigationController *picker = [[ABPeoplePickerNavigationController alloc] init];
    picker.peoplePickerDelegate = self;
    
    // Display only a person's phone, email, and birthdate
    NSArray *displayedItems = @[@(kABPersonPhoneProperty), @(kABPersonEmailProperty), @(kABPersonBirthdayProperty)];
    picker.displayedProperties = displayedItems;
    
    // Show the picker
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark Display and edit a person
// Called when users tap "Display and Edit Contact" in the application. Searches for a contact named "Appleseed" in
// in the address book. Displays and allows editing of all information associated with that contact if
// the search is successful. Shows an alert, otherwise.
-(void)showPersonViewController
{
    // Search for the person named "Appleseed" in the address book
    NSArray *people = (NSArray *)CFBridgingRelease(ABAddressBookCopyPeopleWithName(self.addressBook, CFSTR("Appleseed")));
    // Display "Appleseed" information if found in the address book
    if ((people != nil) && [people count])
    {
        ABRecordRef person = (__bridge ABRecordRef)people[0];
        ABPersonViewController *pvc = [[ABPersonViewController alloc] init];
        pvc.personViewDelegate = self;
        pvc.displayedPerson = person;
        // Allow users to edit the person’s information
        pvc.allowsEditing = YES;
        [self.navigationController pushViewController:pvc animated:YES];
    }
    else
    {
        // Show an alert if "Appleseed" is not in Contacts
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error"
                                                                       message:@"Could not find Appleseed in the Contacts application."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark Create a new person
// Called when users tap "Create New Contact" in the application. Allows users to create a new contact.
-(void)showNewPersonViewController
{
    ABNewPersonViewController *npvc = [[ABNewPersonViewController alloc] init];
    npvc.newPersonViewDelegate = self;
    
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:npvc];
    [self presentViewController:navigation animated:YES completion:nil];
}

#pragma mark Add data to an existing person
// Called when users tap "Edit Unknown Contact" in the application.
-(void)showUnknownPersonViewController
{
    ABRecordRef aContact = ABPersonCreate();
    CFErrorRef anError = NULL;
    ABMultiValueRef email = ABMultiValueCreateMutable(kABMultiStringPropertyType);
    bool didAdd = ABMultiValueAddValueAndLabel(email, @"John-Appleseed@mac.com", kABOtherLabel, NULL);
    
    if (didAdd == YES)
    {
        ABRecordSetValue(aContact, kABPersonEmailProperty, email, &anError);
        if (anError == NULL)
        {
            ABUnknownPersonViewController *upvc = [[ABUnknownPersonViewController alloc] init];
            upvc.unknownPersonViewDelegate = self;
            upvc.displayedPerson = aContact;
            upvc.allowsAddingToAddressBook = YES;
            upvc.allowsActions = YES;
            upvc.alternateName = @"John Appleseed";
            upvc.title = @"John Appleseed";
            upvc.message = @"Company, Inc";
            
            [self.navigationController pushViewController:upvc animated:YES];
        }
        else
        {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error"
                                                                           message:@"Could not create unknown user."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }
    CFRelease(email);
    CFRelease(aContact);
}

#pragma mark ABPeoplePickerNavigationControllerDelegate methods
// The selected person and property from the people picker.
- (void)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker didSelectPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier
{
    NSString *contactName = CFBridgingRelease(ABRecordCopyCompositeName(person));
    NSString *propertyName = CFBridgingRelease(ABPersonCopyLocalizedPropertyName(property));
    NSString *message = [NSString stringWithFormat:@"Picked %@ for %@", propertyName, contactName];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Picker Result"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

// Implement this if you want to do additional work when the picker is cancelled by the user.
- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker
{
}

#pragma mark ABPersonViewControllerDelegate methods
// Does not allow users to perform default actions such as dialing a phone number, when they select a contact property.
- (BOOL)personViewController:(ABPersonViewController *)personViewController shouldPerformDefaultActionForPerson:(ABRecordRef)person
                    property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifierForValue
{
    return NO;
}


#pragma mark ABNewPersonViewControllerDelegate methods
// Dismisses the new-person view controller.
- (void)newPersonViewController:(ABNewPersonViewController *)newPersonViewController didCompleteWithNewPerson:(ABRecordRef)person
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark ABUnknownPersonViewControllerDelegate methods
// Dismisses the picker when users are done creating a contact or adding the displayed person properties to an existing contact. 
- (void)unknownPersonViewController:(ABUnknownPersonViewController *)unknownPersonView didResolveToPerson:(ABRecordRef)person
{
    [self.navigationController popViewControllerAnimated:YES];
}

// Does not allow users to perform default actions such as emailing a contact, when they select a contact property.
- (BOOL)unknownPersonViewController:(ABUnknownPersonViewController *)personViewController shouldPerformDefaultActionForPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier
{
    return NO;
}

#pragma mark Memory management

- (void)dealloc
{
    if(_addressBook)
    {
        CFRelease(_addressBook);
    }
}


@end

