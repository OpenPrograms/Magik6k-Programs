id 'p6'
name 'p6 Kernel'
description 'Kernel for OpenPosix System.'
note 'To boot that kernel, the multiboot bootloader is required. Install on top os OpenOS installation'

install 'p6.lua' => '//boot/kernel/p6'
install 'mod_init.lua' => '//lib/modules/init.lua'

authors 'Magik6k'
