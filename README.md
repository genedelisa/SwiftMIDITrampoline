# SwiftMIDITrampoline

How to use Core MIDI's C callbacks in Swift via an Objective-C trampoline.

Swift does not support C function pointers.

I didn't include an Bonjour code here, so use the Audio MIDI Setup utility to connect to a network session.


## Blog post for this example.

[Blog post](http://www.rockhoppertech.com/blog/swift-midi-trampoline/)

## Update

For fun, I just added a virtual destination and a MusicSequence connected to it. The virtual destination uses the same read proc trampoline as the regular input port. In this example, the textView will echo events on the input port. The MusicSequence will echo to stdout and play the notes at the same time.

You will need to download a SoundFont. I use the one from MuseCore.


## Bugs

Don't see any. Do you?'


### Buy my kitty Giacomo some cat food

[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donate_SM.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=F5KE9Z29MH8YQ&bnP-DonationsBF:btn_donate_SM.gif:NonHosted)

<img src="http://www.rockhoppertech.com/blog/wp-content/uploads/2015/05/IMG_0657.png" alt="Giacomo Kitty" width="400" height="300">

## Licensing

I'd appreciate an ack somehow.

## Credits

*	[Gene De Lisa](http://rockhoppertech.com/blog/)