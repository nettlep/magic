# The Nettle Magic Project

This deck of cards has a bar code printed on the edge of each card. Scanning these bar codes would reveal where every card is (or isn't - if cards are missing.)

Think card magic.

![A deck of cards with digital marks printed on the edge of each card.](docs/img/stamped-deck.jpg)

This wouldn't be a very good magic trick if you could see the marks. We need invisible marks.

One of these decks is unmarked, the other is marked with this special ink that is only visible under specific IR conditions.

![Two decks of cards - each viewed from the same end. Both decks appear normal.](docs/img/ink_comparison.jpg)

This device (a Raspberry Pi Zero W with a NoIR camera) can see these marks. The shiny circle is a special IR filter.

A scanning server runs on this small device.

![A small computer module, about the size of a thumb. It has a small camera attached. The lens of the camera is covered with what looks like s small round mirror.](docs/img/device.png)

This is Abra, the iOS client application running on my iPad. It shows what the server's camera sees along with the decoded deck. As you can see, the IR marks are quite visible to the camera.

![A screenshot of an app containing an array of playing cards in suit and numerical order, with a black-and-white image of a deck of playing cards with edge-marks clearly visible.](docs/img/abra_ipad.png)

Your iDevices can also be a server, but they can't see those infrared marks, even with special filters. However, they can see black ink marks and marks made using a different type of invisible ink - ultraviolet fluorescing ink.

![A deck of cards with marks on the edges of cards that are glowing brightly under the light of a UV pen light. Next to the deck is an iPad showing the deck from it's camera's perspective.](docs/img/uv-ink.jpg)

For hard core developers, I've included the testbed, which has a bunch of visualization tools to understand how things work.

![A screenshot of an app that shows a deck of cards in a viewport with marks outlined digitally, and various statistics listed below.](docs/img/steve.png)

The testbed only runs on Mac. However, the server app is a generic Linux console app and it includes a text-based GUI mode.

![A text-based console app with an image of a deck of cards printed using alphanumeric characters. Statistics appear below this text-based viewport.](docs/img/whisper.png)

Performance is critical.

The statistical model requires a full 30Hz of data. Also, this can be strapped to a person's body during a performance. Efficiency means longer battery, less heat.

It can scan/decode a 1080p image to an ordered deck in as little as 4ms. On a rPI.

# Get started

Full documentation is available [here](https://nettlep.github.io/magic/).
