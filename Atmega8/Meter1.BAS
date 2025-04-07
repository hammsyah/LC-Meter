
'                                                                                 INDUCTANCE METER

'  Origional code from     http://www.rototron.info/projects/inductance-meter/


'
' For Atmega8                       Fuses         LOW CE    HIGH D9  


$regfile = "m8DEF.dat"
$crystal = 10000000

Config Lcd = 16 * 2
Config Lcdpin = Pin , Db4 = Portc.3 , Db5 = Portc.2 , Db6 = Portc.1 , Db7 = Portc.0 , E = Portc.4 , Rs = Portc.5
Cursor Off Noblink

'Set up timer0 to count frequency
Config Timer0 = Counter , Edge = Rising
'Handle frequency timer overflow
On Timer0 Timer0_overflow
'Track number of frequency couter overflows between measurements
Dim Overflow_count As Long
Overflow_count = 0

Dim Freq As Single
Dim Inductance As Single

'Calibration factors
Dim Fcal As Single
Dim Ical As Single

'Set default calibration
Fcal = 390000.25
Ical = 65.115398

Dim W_temp As Word
'Flag designates calibration mode is active
Dim Calibrate As Bit
Calibrate = 0

'Flag designates lock mode is active
Dim Lock As Bit
Lock = 0

'Inductance formula constant 4 x Pi^2
Const Ifactor = 39.4784176043574

'Set up timer to track time
Config Timer1 = Timer , Prescale = 256

Stop Timer1
'Preload timer constant for 1 second duration at 10 MHz
Const Timer1pre = 26472
Timer1 = Timer1pre
'Handle time overflow (occurs every second)
On Timer1 Pulse

Start Timer0
Start Timer1
Enable Interrupts
Enable Timer0
Enable Timer1

'Set port B pins  as inputs except PB2 which fires opto
Ddrb = &B00000100
'Turn on internal pull-up resistors for port B pins
'Set PB2 low
Portb = &B11111011

'Set port D pins  as inputs
Ddrd = &B00000000
'Turn on internal pull-up resistors for port D pins
Portd = &B11111111

'Set up lock character
Deflcdchar 0 , 14 , 17 , 17 , 31 , 27 , 27 , 31 , 31
Wait 1

Do

'Check if calibration button pressed                         CALABRATION PIND.2
If Pind.2 = 0 Then
   'Only run calibration once per button press
   'Do not allow calibration in lock mode
   If Pinb.2 = 0 And Lock = 0 Then
      'Activate relay to ground base inductor
      Set Portb.2
      'Set calibrate mode flag
      Calibrate = 1
      'Wait to allow calibration to obtain frequency
      Wait 3
      Stop Timer0
      Stop Timer1

      'Calculate frequency calibration factor
      Fcal = Freq * Freq
      'Calculate inducatance calibration factor
      Ical = Fcal * Ifactor
      'Adjust by capacitor value (1000pF)
      Ical = Ical * .000000001
      Ical = 1 / Ical

      Cls
      'Lcd "fCal:" ; Fcal
      'Lowerline
      'Lcd "iCal:" ; Ical
      Lcd "Calibration"
      Lowerline
      Lcd "Completed..."

      'End calibration mode
      Calibrate = 0

      'Switch relay back to inductance measurement position
      Reset Portb.2

      'Reset timers
      Counter0 = 0
      Overflow_count = 0
      Start Timer0
      Timer1 = Timer1pre
      Start Timer1
   End If
End If

If Pind.1 = 0 And Calibrate = 0 Then
   ' Enable lock mode (button 2) (except if calibrating)                PIND.1 LOCK MODE
   If Lock = 0 Then
      Lock = 1
      Stop Timer0
      Stop Timer1
      'set cursor position
      Locate 1 , 16
      Lcd Chr(0)

   End If
End If

If Pind.0 = 0 Then
   ' Disable lock mode (button3)                                      PIND.0 DISABLE LOCK MODE
   If Lock = 1 Then
      Lock = 0
      'Reset timers
      Counter0 = 0
      Overflow_count = 0
      Start Timer0
      Timer1 = Timer1pre
      Start Timer1
    End If
End If


Loop

'Track frequency overflows
Timer0_overflow:
   Incr Overflow_count
   Return

'Measure frequency and inductance on timer1 overflow
Pulse:
   Stop Timer0
   Stop Timer1
   Cls

   'Calculate frequency
   W_temp = Counter0
   Freq = Overflow_count * 256
   Freq = Freq + W_temp
   'Adjust frequncy from Hertz to KiloHertz
   Freq = Freq * .001

   'Calculate inductance
   Inductance = Freq * Freq
   'Skip if frequency below minimum to avoid divide by zero error
   If Inductance > 10 Then
      Inductance = Fcal / Inductance
      Inductance = Inductance - 1
      Inductance = Inductance * Ical
   End If

   'Update LCD display based on mode
   If Calibrate = 1 Then
      Lcd "* Calibrating *"
      Lowerline
      Lcd "Please Wait..."
   Else
      Lcd Fusing(freq , "#.##") ; " kHz"
      Lowerline
      Lcd Fusing(inductance , "#.##") ; " uH"
   End If

   'Reset counters
   Counter0 = 0
   Overflow_count = 0
   Start Timer0
   Timer1 = Timer1pre
   Start Timer1
   Return

End