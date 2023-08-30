
# Automatic ROBLOX audio-related things script

Designed to be used with Lune, basically just [Tarmac](https://github.com/Roblox/tarmac) but for audio

(i got bored)

  

supports both uploading (+authenticating) and bulk authentication

  

# Usage

1. Install Lune by running ``aftman install`` in the directory

2. Place your files in a subfolder

3. Run ``lune main`` and follow the instructions

  

# Info

``lune main`` does support passing arguments right away, so you don't need to go through the prompts, but can instead use:

if uploading:

``lune main upload <subfolder> <mode> <user_type> <user_id> <api_key> [experience_ids]``

if authenticating:

``lune main authenticate <subfolder> <experience_ids>``

  

Explanation of flags:

- subfolder: subfolder to grab the audio from

- mode:
	* ``rbxm``: creates a rbxm file based on your output (contains the folders as Folders and the .ogg/.mp3 sounds as Sounds with their SoundIds set)
	* ``folders``: creates a folder structure based on your source folder, but with the .ogg/.mp3 files replaced with .lua files that return the sound ID
	* ``module``: creates a .lua file that returns a table based on your source folder. I'd not recommend interacting with the source of this module, just place it somewhere and, for your own sanity, just leave it there (the string to table implementation I made is made to work and nothing more than that, so it just leaves this non-indented mess)
- ``user_type``: ``group`` or ``user``
- ``user_id``: with a ``group``, the group id, with a ``user``, the user id
- ``api_key``: your open cloud api key, you can generate this over [here](https://create.roblox.com/dashboard/credentials)
- ``experience_ids``: the experience ids that you want your sounds to be authenticated under. seperated by comma, and you can pass ``none`` if you're on the ``upload`` mode if you don't want to authenticate them (but ROBLOX is being annoying with this, so I wouldn't recommend it)