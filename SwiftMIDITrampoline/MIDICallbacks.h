//
//  MIDICallbacks.h
//  SwiftMIDITrampoline
//
//  Created by Gene De Lisa on 6/3/15.
//  Copyright (c) 2015 Gene De Lisa. All rights reserved.
//


@import CoreMIDI;

#ifndef SwiftMIDITrampoline_MIDICallbacks_h
#define SwiftMIDITrampoline_MIDICallbacks_h


OSStatus MIDIClientCreate_withBlock(MIDIClientRef *outClient, CFStringRef name, void (^notifyRefCon)(const MIDINotification *message));

OSStatus MIDIInputPortCreate_withBlock(MIDIClientRef midiClient, CFStringRef name, MIDIPortRef* outport, void (^readRefCon)(const MIDITimeStamp ts, const UInt8 *datum, const UInt16 len));

OSStatus MIDIDestinationCreate_withBlock(MIDIClientRef midiClient, CFStringRef name, MIDIEndpointRef* virtualDestination, void (^readRefCon)(const MIDITimeStamp ts, const UInt8 *data, const UInt16 len));


#endif
