' Clock Initialisation
_clkmode = xtal1 + pll16x
_xinfreq = 5_000_000
_ConClkFreq = ((_clkmode - xtal1) >> 6) * _xinfreq
_Ms_001   = _ConClkFreq / 1_000
' ------------------------------------------------

' Config
mot_Shutdown1n2 = 0
mot_1Stop = 64
mot_2Stop = 192

' Motor Commands
motCmdStopAll   = 0   ' Stop all motors
motCmdForward   = 1   ' Forward
motCmdReverse   = 2   ' Reverse
motCmdSetMot    = 3   ' Setting individual motors
motCmdMcTR      = 4   ' Example command (you can modify or remove this)
motCmdMcTL      = 5   ' Example command (you can modify or remove this)
motCmdMcSLeft   = 6   ' Example command (you can modify or remove this)
motCmdMcSRight  = 7   ' Example command (you can modify or remove this)

OBJ
  MD1       : "FullDuplexSerial.spin"                   '<-- Replace with UART4
  MD2       : "FullDuplexSerial.spin"
  SSComm    : "FDS4FC.spin"
  Def       : "RxBoardDef.spin"

VAR
  long  mainHubMS
  long  cog, cogStack[64]

DAT

PUB Main | i, j, k

  ' Main(): This function is for testing purposes only.
  ' It initializes two instances of a full-duplex serial object, MD1 and MD2, and then waits for 500 milliseconds.

  mainHubMS := _Ms_001

  SSComm.AddPort(0, Def#R1S2, Def#R1S1, SSComm#PINNOTUSED, SSComm#PINNOTUSED, SSComm#DEFAULTTHRESHOLD, %000000, Def#SSBaud)
  SSComm.AddPort(1, Def#R2S2, Def#R2S1, SSComm#PINNOTUSED, SSComm#PINNOTUSED, SSComm#DEFAULTTHRESHOLD, %000000, Def#SSBaud)
  SSComm.Start
  Pause(500)
  FullMotionTest

PUB ActMC(mainMS, DirPtr, Spd)

  ' This function starts a new cog (processor) and loads it with the motorCore function, which controls the motors.

  mainHubMS := mainMS
  Stop
  cog := cognew(StartMC(DirPtr,Spd), @CogStack) + 1

  return cog

PUB StartMC(DirPtr,Spd) 'Track Selection

  SSComm.AddPort(0, Def#R1S2, Def#R1S1, SSComm#PINNOTUSED, SSComm#PINNOTUSED, SSComm#DEFAULTTHRESHOLD, %000000, Def#SSBaud)
  SSComm.AddPort(1, Def#R2S2, Def#R2S1, SSComm#PINNOTUSED, SSComm#PINNOTUSED, SSComm#DEFAULTTHRESHOLD, %000000, Def#SSBaud)
  SSComm.Start
  Pause(1000)
  AllMotorStop                                                                 'Calibrate RoboClaw to new zero point value
  Pause(1000)



  repeat
    case BYTE[DirPtr]                                                           'Update direction using Op-Code
        0:
          AllMotorStop
        1:
          Forward(LONG[Spd])
        2:
          Reverse(LONG[Spd])
        3:
          Left(LONG[Spd])
        4:
          Right(LONG[Spd])
        5:
          MecanumForwardLeft(LONG[Spd])
        6:
          MecanumForwardRight(LONG[Spd])
        7:
          MecanumReverseLeft(LONG[Spd])
        8:
          MecanumReverseRight(LONG[Spd])
        11:
          StrafeLeft(LONG[Spd])
        12:
          StrafeRight(LONG[Spd])

PUB Start(mainMS, Cmd, AllDutyCycle, motOrient, motDCycle)

  ' This function starts a new cog (processor) and loads it with the motorCore function, which controls the motors.

  mainHubMS := mainMS
  Stop
  cog := cognew(motorCore(Cmd, AllDutyCycle, motOrient, motDCycle), @cogStack) + 1

  return cog


PUB Stop

  ' Stop & Release Core

  if cog
    cogstop(cog~ - 1)    'stops and releases the cog used by the motor core.

  return


PUB motorCore(Cmd, AllDutyCycle, motOrient, motDCycle) | i, k, j

  ' Load core for motor

  SSComm.AddPort(0, Def#R1S2, Def#R1S1, SSComm#PINNOTUSED, SSComm#PINNOTUSED, SSComm#DEFAULTTHRESHOLD, %000000, Def#SSBaud)
  SSComm.AddPort(1, Def#R2S2, Def#R2S1, SSComm#PINNOTUSED, SSComm#PINNOTUSED, SSComm#DEFAULTTHRESHOLD, %000000, Def#SSBaud)
  SSComm.Start

  Pause(500)

  repeat    'takes in cmd input and executes the corresponding direction
    case long[Cmd]
      motCmdStopAll:  ' Stop All Motors
        AllMotorStop

      motCmdForward:  ' Forward
        Forward(long[AllDutyCycle])

      motCmdReverse:  ' Reverse
        Reverse(long[AllDutyCycle])

      motCmdSetMot:   ' Setting individual motors
        repeat i from 0 to 3
          k := long[motOrient] & ($FF << (i*8))
          j := long[motDCycle] & ($FF << (i*8))
          SetMotor(i+1, k >> (i*8), j >> (i*8))

      motCmdMcTR:
        long[motOrient] := 1 << 24 | 1 << 16 | 1 << 8 | 1
        long[motDCycle] := long[AllDutyCycle] << 24 | long[AllDutyCycle] << 16 | long[AllDutyCycle] << 8 | long[AllDutyCycle]
        i := 1
        k := long[motOrient] & ($FF << (i*8))
        j := long[motDCycle] & ($FF << (i*8))
        SetMotor(i+1, k >> (i*8), j >> (i*8))
        i := 2
        k := long[motOrient] & ($FF << (i*8))
        j := long[motDCycle] & ($FF << (i*8))
        SetMotor(i+1, k >> (i*8), j >> (i*8))

      motCmdMcTL:
        long[motOrient] := 1 << 24 | 1 << 16 | 1 << 8 | 1
        long[motDCycle] := long[AllDutyCycle] << 24 | long[AllDutyCycle] << 16 | long[AllDutyCycle] << 8 | long[AllDutyCycle]
        i := 0
        k := long[motOrient] & ($FF << (i*8))
        j := long[motDCycle] & ($FF << (i*8))
        SetMotor(i+1, k >> (i*8), j >> (i*8))
        i := 3
        k := long[motOrient] & ($FF << (i*8))
        j := long[motDCycle] & ($FF << (i*8))
        SetMotor(i+1, k >> (i*8), j >> (i*8))

      motCmdMcSLeft:
        long[motOrient] := 1 << 24 | 0 << 16 | 0 << 8 | 1
        long[motDCycle] := long[AllDutyCycle] << 24 | long[AllDutyCycle] << 16 | long[AllDutyCycle] << 8 | long[AllDutyCycle]
        repeat i from 0 to 3
          k := long[motOrient] & ($FF << (i*8))
          j := long[motDCycle] & ($FF << (i*8))
          SetMotor(i+1, k >> (i*8), j >> (i*8))

      motCmdMcSRight:
        long[motOrient] := 0 << 24 | 1 << 16 | 1 << 8 | 0
        long[motDCycle] := long[AllDutyCycle] << 24 | long[AllDutyCycle] << 16 | long[AllDutyCycle] << 8 | long[AllDutyCycle]
        repeat i from 0 to 3
          k := long[motOrient] & ($FF << (i*8))
          j := long[motDCycle] & ($FF << (i*8))
          SetMotor(i+1, k >> (i*8), j >> (i*8))


PUB SetMotor(MotNum, Orientation, DutyCycle) | i, compValue

  ' DutyCycle specifies the duty cycle as a value between 1 and 100
  DutyCycle := DutyCycle <#= 100
  DutyCycle := DutyCycle #>= 1
  compValue := (DutyCycle * 63) / 100

  case MotNum
    1..2:  ' Motors 1 and 2
      case Orientation
        0:  ' Reverse
          case MotNum
            1:
              SSComm.Tx(0, 64 - compValue)  ' Motor 1 reverse
            2:
              SSComm.Tx(0, 192 - compValue)  ' Motor 2 reverse
        1:  ' Forward
          case MotNum
            1:
              SSComm.Tx(0, 64 + compValue)  ' Motor 1 forward
            2:
              SSComm.Tx(0, 192 + compValue)  ' Motor 2 forward
    3..4:  ' Motors 3 and 4
      case Orientation
        0:  ' Reverse
          case MotNum
            3:
              SSComm.Tx(1, 64 - compValue)  ' Motor 3 reverse
            4:
              SSComm.Tx(1, 192 - compValue)  ' Motor 4 reverse
        1:  ' Forward
          case MotNum
            3:
              SSComm.Tx(1, 64 + compValue)  ' Motor 3 forward
            4:
              SSComm.Tx(1, 192 + compValue)  ' Motor 4 forward

  return
PUB Forward(DutyCycle) | i, compValue    'Moves Forward

  DutyCycle := DutyCycle <#= 100
  DutyCycle := DutyCycle #>= 1
  compValue := (DutyCycle * 63)/100

  SSComm.Tx(0, 64 - compValue )                         'FrontRight M1 -
  SSComm.Tx(0, 192 - compValue )                        'FrontLeft M2-
  SSComm.Tx(1, 64 - compValue )                         'BackRight M3-
  SSComm.Tx(1, 192 - compValue )                        'BackLeft M4-

  return


PUB Reverse(DutyCycle) | i, compValue    'Moves Backwards

  DutyCycle := DutyCycle <#= 100
  DutyCycle := DutyCycle #>= 1
  compValue := (DutyCycle * 63)/100

  SSComm.Tx(0, 64 + compValue )
  SSComm.Tx(0, 192 + compValue )
  SSComm.Tx(1, 64 + compValue )
  SSComm.Tx(1, 192 + compValue )
  return


PUB AllMotorStop | i    'Stops all motors

  repeat i from 0 to 1
    SSComm.Tx(i, 0)

  return


PUB testMotors | i    'Test to see if motors are working

  Pause(1000)
  repeat
    repeat i from mot_1Stop to 1 step 1
      SSComm.Tx(0, i)
      Pause(100)
    repeat i from 1 to mot_1Stop step 1
      SSComm.Tx(0, i)
      Pause(100)


PRI Pause(ms) | t

  t := cnt - 1088    ' sync with system counter
  repeat (ms #> 0)   ' delay must be > 0
    waitcnt(t += mainHubMS)

  return


PUB TestSetMotor | i, j    'Test to see if motors are moving as intended

' Forward
  repeat j from 1 to 100
    repeat i from 1 to 4
      SetMotor(i, 1, j)
    Pause(50)
  repeat j from 100 to 1
    repeat i from 1 to 4
      SetMotor(i, 1, j)
    Pause(50)

  AllMotorStop

' Reverse
  repeat j from 1 to 100
    repeat i from 1 to 4
      SetMotor(i, 0, j)
    Pause(50)
  repeat j from 100 to 1
    repeat i from 1 to 4
      SetMotor(i, 0, j)
    Pause(50)

  AllMotorStop

  return


PUB FullMotionTest | i    'Test all directions implemented
  repeat
    StrafeLeft(30)
    Pause(3000)

  return


PUB MecanumForwardLeft(DutyCycle) | diagonalSpeed  , compValue


  DutyCycle := DutyCycle <#= 100
  DutyCycle := DutyCycle #>= 1
  compValue := (DutyCycle * 63)/100

  SSComm.Tx(0, 64 - compValue)
  SSComm.Tx(0, 192)
  SSComm.Tx(1, 64  )
  SSComm.Tx(1, 192 - compValue)

  return

PUB MecanumForwardRight(DutyCycle) | diagonalSpeed  , compValue

  DutyCycle := DutyCycle <#= 100
  DutyCycle := DutyCycle #>= 1
  compValue := (DutyCycle * 63)/100

  SSComm.Tx(0, 64)
  SSComm.Tx(0, 192 - compValue)
  SSComm.Tx(1, 64 - compValue)
  SSComm.Tx(1, 192)

  return

PUB MecanumReverseLeft(DutyCycle) | diagonalSpeed   , compValue


  DutyCycle := DutyCycle <#= 100
  DutyCycle := DutyCycle #>= 1
  compValue := (DutyCycle * 63)/100

  SSComm.Tx(0, 64)
  SSComm.Tx(0, 192 + compValue)
  SSComm.Tx(1, 64 + compValue)
  SSComm.Tx(1, 192)

  return

PUB MecanumReverseRight(DutyCycle) | diagonalSpeed  , compValue


  DutyCycle := DutyCycle <#= 100
  DutyCycle := DutyCycle #>= 1
  compValue := (DutyCycle * 63)/100

  SSComm.Tx(0, 64 + compValue)
  SSComm.Tx(0, 192)
  SSComm.Tx(1, 64  )
  SSComm.Tx(1, 192 + compValue)

  return

PUB Right(DutyCycle) | diagonalSpeed  , compValue


  DutyCycle := DutyCycle <#= 100
  DutyCycle := DutyCycle #>= 1
  compValue := (DutyCycle * 63)/100

  SSComm.Tx(0, 64 + compValue)
  SSComm.Tx(0, 192 + compValue)
  SSComm.Tx(1, 64 + compValue )
  SSComm.Tx(1, 192 - compValue)
  return

PUB Left(DutyCycle) | diagonalSpeed  , compValue


  DutyCycle := DutyCycle <#= 100
  DutyCycle := DutyCycle #>= 1
  compValue := (DutyCycle * 63)/100

  SSComm.Tx(0, 64 - compValue )                         'FrontRight -
  SSComm.Tx(0, 192 - compValue )                        'FrontLeft +
  SSComm.Tx(1, 64 - compValue )                         'Backleft  +
  SSComm.Tx(1, 192 + compValue )                        'BackRight +
  return

PUB StrafeLeft(DutyCycle) | diagonalSpeed  , compValue


  DutyCycle := DutyCycle <#= 100
  DutyCycle := DutyCycle #>= 1
  compValue := (DutyCycle * 63)/100

  SSComm.Tx(0, 64 - compValue )
  SSComm.Tx(0, 192 + compValue )
  SSComm.Tx(1, 64 + compValue )
  SSComm.Tx(1, 192 - compValue )
  return

PUB StrafeRight(DutyCycle) | diagonalSpeed  , compValue


  DutyCycle := DutyCycle <#= 100
  DutyCycle := DutyCycle #>= 1
  compValue := (DutyCycle * 63)/100

  SSComm.Tx(0, 64 + compValue )
  SSComm.Tx(0, 192 - compValue )
  SSComm.Tx(1, 64 - compValue )
  SSComm.Tx(1, 192 + compValue )
  return

PUB PivotRight(DutyCycle) | diagonalSpeed  , compValue


  DutyCycle := DutyCycle <#= 100
  DutyCycle := DutyCycle #>= 1
  compValue := (DutyCycle * 63)/100

  SSComm.Tx(0, 64 - compValue )
  SSComm.Tx(0, 192 )
  SSComm.Tx(1, 64 + compValue)
  SSComm.Tx(1, 192)
  return

PUB NegPivotRight(DutyCycle) | diagonalSpeed  , compValue


  DutyCycle := DutyCycle <#= 100
  DutyCycle := DutyCycle #>= 1
  compValue := (DutyCycle * 63)/100

  SSComm.Tx(0, 64 + compValue )
  SSComm.Tx(0, 192 )
  SSComm.Tx(1, 64 - compValue)
  SSComm.Tx(1, 192)
  return

PUB Pivotleft (DutyCycle) | diagonalSpeed  , compValue


  DutyCycle := DutyCycle <#= 100
  DutyCycle := DutyCycle #>= 1
  compValue := (DutyCycle * 63)/100

  SSComm.Tx(0, 64 )
  SSComm.Tx(0, 192 + compValue )
  SSComm.Tx(1, 64 )
  SSComm.Tx(1, 192 + compValue)
  return


PUB NegPivotleft (DutyCycle) | diagonalSpeed  , compValue


  DutyCycle := DutyCycle <#= 100
  DutyCycle := DutyCycle #>= 1
  compValue := (DutyCycle * 63)/100

  SSComm.Tx(0, 64 )
  SSComm.Tx(0, 192 - compValue )
  SSComm.Tx(1, 64 )
  SSComm.Tx(1, 192 - compValue)
  return