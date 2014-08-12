id 'multiboot'
name 'Simple and light bootloader'
description 'A simple program that allows booting multiple systems. INSTALLING IT WILL OVERWRITE init.lua, install it using -f option. Installing it in OpenOS should be safe'


install 'init.lua' => '//init.lua'
install 'openos.lua' => '//boot/kernel/OpenOS'

authors 'Magik6k'
