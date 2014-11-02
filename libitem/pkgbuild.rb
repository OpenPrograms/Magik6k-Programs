id 'libitem'
name 'Item library'
description 'Library simplifying NBT tag reading from inventory controller'

depend ['libdeflate', 'libnbt']

install 'item.lua' => '/lib'
install 'iview.lua' => '/bin'

authors 'Magik6k'
