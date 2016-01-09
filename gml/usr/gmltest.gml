<gml>
  <meta>
    <title>gmltest</title>
    <author>GopherAtl</author>
    <desc>A test program for the GML gui library</desc>
  </meta>
  <frame>
    <name>testgui</name>
    <x>center</x>
    <y>center</y>
    <w>32</w>
    <h>19</h>
    <children>
      <label>
        <name>label1</name>
        <x>center</x>
        <y>2</y>
        <w>13</w>
        <text>Hello, World!</text>
      </label>
      <field>
      	<name>field1</name>
        <x>center</x>
        <y>4</y>
        <w>18</w>
      </field>
      <button>
      	<name>button1</name>
        <x>4</x>
        <y>6</y>
        <w>10</w>
        <h>1</h>
        <text>Toggle</text>
        <onClick> 
          <<
          function()
            if label1.visible then
              label1:hide()
            else
              label1:show()
            end
          end>>
        </onClick>
      </button>
      <button>
      	<name>button2</name>
        <x>-4</x>
        <y>6</y>
        <w>10</w>
        <h>1</h>
        <text>Close</text>
        <onClick><<testgui.close>></onClick>
      </button>
      <scrollBarV>
        <name>scrollV</name>
        <x>-1</x>
        <y>1</y>
        <h>16</h>
        <maxScroll>100</maxScroll>
        <onScroll><<setLabelToScroll>></onScroll>
      </scrollBarV>
      <scrollBarH>
        <name>scrollH</name>
        <x>1</x>
        <y>-1</y>
        <w>29</w>
        <maxScroll>100</maxScroll>
        <onScroll><<setLabelToScroll>></onScroll>
      </scrollBarH>
      <label>
        <name>label2</name>
        <x>-2</x>
        <y>-2</y>
        <w>7</w>
      </label>
      <listbox>
      	<name>listbox1</name>
        <x>center</x>
        <y>8</y>
        <w>16</w>
        <h>8</h>
        <list>
          {
            "one", "two", "three", "four", "five", "six", "seven", 
            "eight", "nine", "ten", "eleven", "twelve", "thirteen",
            "fourteen", "fifteen", "sixteen", "seventeen",
            "eighteen", "nineteen", "twenty", "twenty-one", 
            "twenty-two", "twenty-three", "twenty-four", "twenty-five"
          }
        </list>
      </listbox>
    </children>
  </frame>
  <code>
    <function>
      <name>setLabelToScroll</name>
      <body>
        <<
          label2.text=string.format("%3s,%3s",scrollH.scrollPos,scrollV.scrollPos)
          label2:draw()
        >>
      </body>
    </function>
    <handler>
      <event>key_down</event>
      <body>
        <<
          function(event,addy,char,key)
            --ctrl-r
            if char==18 then
              local fg,bg=component.gpu.getForeground(), component.gpu.getBackground()
              label["text-color"]=math.random(0,0xffffff)
              label1:draw()
              component.gpu.setForeground(fg)
              component.gpu.setBackground(bg)
            end
          end
        >>
      </body>
    </handler>
    <require>component</require>
    <require>otherThing</require>
     
    <<
label1:hide()

label2.text="  0,  0"

    >>
  </code>
</gml>