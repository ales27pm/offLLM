package com.myofflinellmapp;

import android.content.ContentProviderOperation;
import android.content.ContentResolver;
import android.database.Cursor;
import android.provider.ContactsContract;
import androidx.annotation.NonNull;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableNativeArray;
import com.facebook.react.bridge.WritableNativeMap;
import com.facebook.react.module.annotations.ReactModule;
import java.util.ArrayList;

/**
 * ContactsTurboModule provides basic contact lookup and insertion on
 * Android devices. The implementation makes use of the Contacts
 * Provider to perform queries and modifications. Caller must ensure
 * that READ_CONTACTS and WRITE_CONTACTS permissions have been granted.
 */
@ReactModule(name = ContactsTurboModule.NAME)
public class ContactsTurboModule extends ReactContextBaseJavaModule {
    public static final String NAME = "ContactsTurboModule";

    public ContactsTurboModule(ReactApplicationContext reactContext) {
        super(reactContext);
    }

    @NonNull
    @Override
    public String getName() {
        return NAME;
    }

    @ReactMethod
    public void findContact(String query, Promise promise) {
        ReactApplicationContext ctx = getReactApplicationContext();
        ContentResolver resolver = ctx.getContentResolver();
        WritableArray resultArray = new WritableNativeArray();
        Cursor contactsCursor = null;
        try {
            String selection = ContactsContract.Contacts.DISPLAY_NAME + " LIKE ?";
            String[] args = new String[]{"%" + query + "%"};
            contactsCursor = resolver.query(
                    ContactsContract.Contacts.CONTENT_URI,
                    new String[]{ContactsContract.Contacts._ID, ContactsContract.Contacts.DISPLAY_NAME},
                    selection, args, null);
            if (contactsCursor != null) {
                while (contactsCursor.moveToNext()) {
                    String contactId = contactsCursor.getString(0);
                    String name = contactsCursor.getString(1);
                    WritableArray phonesArray = new WritableNativeArray();
                    Cursor phoneCursor = resolver.query(
                            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                            new String[]{ContactsContract.CommonDataKinds.Phone.NUMBER},
                            ContactsContract.CommonDataKinds.Phone.CONTACT_ID + "=?",
                            new String[]{contactId}, null);
                    if (phoneCursor != null) {
                        while (phoneCursor.moveToNext()) {
                            String phoneNumber = phoneCursor.getString(0);
                            phonesArray.pushString(phoneNumber);
                        }
                        phoneCursor.close();
                    }
                    WritableArray emailArray = new WritableNativeArray();
                    Cursor emailCursor = resolver.query(
                            ContactsContract.CommonDataKinds.Email.CONTENT_URI,
                            new String[]{ContactsContract.CommonDataKinds.Email.ADDRESS},
                            ContactsContract.CommonDataKinds.Email.CONTACT_ID + "=?",
                            new String[]{contactId}, null);
                    if (emailCursor != null) {
                        while (emailCursor.moveToNext()) {
                            String email = emailCursor.getString(0);
                            emailArray.pushString(email);
                        }
                        emailCursor.close();
                    }
                    WritableMap contactMap = new WritableNativeMap();
                    contactMap.putString("name", name != null ? name : "");
                    contactMap.putArray("phones", phonesArray);
                    contactMap.putArray("emails", emailArray);
                    resultArray.pushMap(contactMap);
                }
            }
            promise.resolve(resultArray);
        } catch (SecurityException e) {
            promise.reject("permission_denied", "Contacts access denied", e);
        } catch (Exception e) {
            promise.reject("search_error", e.getMessage(), e);
        } finally {
            if (contactsCursor != null) contactsCursor.close();
        }
    }

    @ReactMethod
    public void addContact(String name, String phone, String email, Promise promise) {
        try {
            ArrayList<ContentProviderOperation> ops = new ArrayList<>();
            ops.add(ContentProviderOperation.newInsert(ContactsContract.RawContacts.CONTENT_URI)
                    .withValue(ContactsContract.RawContacts.ACCOUNT_TYPE, null)
                    .withValue(ContactsContract.RawContacts.ACCOUNT_NAME, null)
                    .build());
            // Split name into given, middle and family parts for better display. At
            // minimum the full name is stored as given name.
            String givenName = name;
            String middleName = null;
            String familyName = null;
            if (name != null) {
                String[] parts = name.trim().split("\\s+");
                if (parts.length == 1) {
                    givenName = parts[0];
                } else if (parts.length == 2) {
                    givenName = parts[0];
                    familyName = parts[1];
                } else if (parts.length > 2) {
                    givenName = parts[0];
                    familyName = parts[parts.length - 1];
                    StringBuilder middle = new StringBuilder();
                    for (int i = 1; i < parts.length - 1; i++) {
                        if (i > 1) middle.append(" ");
                        middle.append(parts[i]);
                    }
                    middleName = middle.toString();
                }
            }
            ops.add(ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                    .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
                    .withValue(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE)
                    .withValue(ContactsContract.CommonDataKinds.StructuredName.GIVEN_NAME, givenName)
                    .withValue(ContactsContract.CommonDataKinds.StructuredName.MIDDLE_NAME, middleName)
                    .withValue(ContactsContract.CommonDataKinds.StructuredName.FAMILY_NAME, familyName)
                    .build());
            if (phone != null && !phone.isEmpty()) {
                ops.add(ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                        .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
                        .withValue(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE)
                        .withValue(ContactsContract.CommonDataKinds.Phone.NUMBER, phone)
                        .withValue(ContactsContract.CommonDataKinds.Phone.TYPE, ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE)
                        .build());
            }
            if (email != null && !email.isEmpty()) {
                ops.add(ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                        .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
                        .withValue(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.Email.CONTENT_ITEM_TYPE)
                        .withValue(ContactsContract.CommonDataKinds.Email.ADDRESS, email)
                        .withValue(ContactsContract.CommonDataKinds.Email.TYPE, ContactsContract.CommonDataKinds.Email.TYPE_HOME)
                        .build());
            }
            ContentResolver resolver = getReactApplicationContext().getContentResolver();
            resolver.applyBatch(ContactsContract.AUTHORITY, ops);
            WritableMap res = new WritableNativeMap();
            res.putBoolean("success", true);
            promise.resolve(res);
        } catch (SecurityException e) {
            promise.reject("permission_denied", "Contacts access denied", e);
        } catch (Exception e) {
            promise.reject("save_error", e.getMessage(), e);
        }
    }
}
