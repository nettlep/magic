# The Nettle Magic Project

The Nettle Magic Project is a collection of technologies intended to enable magicians (the performing kind, not the occult) to have intimate knowledge of a deck of cards during their performance: the ordered list of every card in the deck, which card(s) are missing and even which cards are face-up in the deck.

A deck of cards is read by scanning card-identifying codes printed on the edges of each card. Decks can be marked with different inks, including some that are virtually invisible to the human eye (UV reactive and IR absorbing inks.)

![Overview of scanning a deck of cards with barcodes marked on the edges of each card](doc/img/intro-stages.png)

**LEFT**: An test deck marked with visible Black ink. **CENTER**: A scanning server running on a Raspberry Pi Zero W with a NoIR camera module and a 5MM IR filter. **RIGHT**: Client software running on an iPad displaying the results of a raw scan from a scanning server. The deck in this image is marked with IR absorbing ink and viewed under IR-viewing conditions.

A marked deck is not needed to experiment with the software. Test videos are included and in a pinch you can print your own marks on a sheet of paper for testing purposes. However, if you plan to work with a physical deck of cards you'll need an edge-marked deck. This document will describe two processes that can be used to apply edge marks to a deck of cards.

The core libraries, along with the production server (_Whisper_) are written to support macOS and Linux, with additional support for the Raspberry Pi platform.

The testbed applications (_Steve_ and _Stevie_) were written specifically for macOS and iOS, respectively. There is currently no Windows support for desktop platforms or Android support for mobile platforms.

Full documentation is available [here](doc/index.md.html).