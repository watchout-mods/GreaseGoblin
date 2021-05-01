Grease Goblin is an Addon that makes writing and distributing small *Scripts* quick and painless. You know the Firefox Add-On [**Greasemonkey**](https://addons.mozilla.org/de/firefox/addon/greasemonkey)? Yes. It's basically just like that.

**Grease Goblin** uses a similar markup as Greasemonkey at the beginning of every script to define when it gets run. This markup is very simple, but cASe-sensitive. Any databases, markup and API are kept as static as possible, so that if you write a script, it will not just  stop working when you update the addon.

The following example demonstrates the whole currently available markup:

```lua
-- OnLoad: true
-- OnEvent: ADDON_LOADED
-- OnEvent: SOME_OTHER_EVENT
print("Hello World!", ...);
```

There is also a chat-command `/ggb` or `/ggoblin` to open a (resizeable) configuration window with only the **Grease Goblin** dialog.

Resources
---------

* [Sample scripts](https://github.com/watchout-mods/GreaseGoblin/wiki/Script-examples)
* [Markup syntax](https://github.com/watchout-mods/GreaseGoblin/wiki/Syntax)
* [API documentation](http://wow.curseforge.com/addons/grease-goblin/pages/api/)
* [Goblin API](https://github.com/watchout-mods/GreaseGoblin/wiki/Goblin-API)

To-Do
-----

* Better UI / editor (It is the WoW text editors that are buggy, so I would have to write a custom text field... Possible, but really annoying)
* Document add-on API using Curse packager
* Option to run a Goblin in secure environment (needs out-of-combat check for compiling)
