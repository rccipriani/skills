#include <adv3.h>
#include <en_us.h>

versionInfo: GameID
    name = 'World and Event Regression'
    byline = 'by the skill regression fixture'
    htmlByline = 'by the skill regression fixture'
    version = '1'
    authorEmail = 'nobody@example.invalid'
    desc = 'A neutral furnished-room and scheduler fixture.'
;

gameMain: GameMainDef
    initialPlayerChar = me
    showIntro() { "World and event regression. [WORLD intro] "; }
;

lab: Room 'Dusty Music Room'
    "A dusty grand piano stands beneath an enormous crystal chandelier.
    An overturned oak chair faces a glass-fronted cabinet. Faded portraits
    hang beside a cracked plaster arch. A brass key lies on the piano.
    [WORLD room=lab] "
    north = hall
    enteringRoom(traveler)
    {
        inherited(traveler);
        if (traveler == me && hasBeenEntered)
            eventControl.noteReturn();
        hasBeenEntered = true;
    }
    hasBeenEntered = true
;

me: Actor location = lab;

chandelier: Fixture 'enormous crystal chandelier/light' 'chandelier' @lab
    "The crystal chandelier is fixed to a ceiling rose. [WORLD chandelier] "
;

portraits: Decoration 'faded dusty portraits/paintings/pictures' 'portraits' @lab
    isPlural = true
    desc = "The faded portraits show unsmiling musicians. [WORLD decoration] "
;

piano: Fixture, Surface
    'dusty grand piano/instrument' 'grand piano' @lab
    "The grand piano is scarred but playable. [WORLD piano] "
    dobjFor(Play)
    {
        verify() { logical; }
        action() { "A flat chord shivers through the room. [WORLD played] "; }
    }
;

brassKey: Thing 'small brass cabinet key' 'brass key' @piano
    "A small brass key. [WORLD portable] "
;

oakChair: Chair 'overturned oak wooden chair/seat' 'oak chair' @lab
    "The oak chair is overturned, but still sturdy enough to sit on.
    [WORLD chair] "
    dobjFor(Move)
    {
        action() { "You set the chair where you want it. [WORLD chair-moved] "; }
    }
    dobjFor(LookUnder)
    {
        action() { "There is only dust beneath the chair. [WORLD under-chair] "; }
    }
;

cabinet: OpenableContainer
    'glass fronted glass-fronted display cabinet/cupboard' 'glass-fronted cabinet' @lab
    "The cabinet is <<isOpen ? 'open' : 'closed'>>. [WORLD cabinet] "
    initiallyOpen = nil
;

+ cabinetNote: Thing 'folded paper inventory note' 'inventory note'
    "The note lists missing instruments. "
;

plasterArch: RoomPart 'cracked plaster arch/archway' 'plaster arch' @lab
    "A hairline crack crosses the plaster arch. [WORLD room-part] "
;

startButton: Button 'black event start button/control' 'start button' @lab
    dobjFor(Push)
    {
        action() { eventControl.startEvents(); }
    }
;

stopButton: Button 'red stop cancel button/control' 'stop button' @lab
    dobjFor(Push)
    {
        action() { eventControl.stopEvents(); }
    }
;

clue: Thing 'silver occult clue/token' 'silver clue' @lab
    "A silver token etched with an eye. "
;

hall: Room 'Stone Hall'
    "A thick stone hall lies north of the music room. [WORLD room=hall] "
    south = lab
;

remoteBell: Fixture 'remote iron bell' 'iron bell' @hall
    "An iron bell hangs here. "
;

eventControl: object
    delayedEvent = nil
    pulseEvent = nil
    senseEvent = nil
    started = nil
    delayedFired = nil
    pulseCount = 0
    stage = 0
    returnCount = 0
    bellChanged = nil

    startEvents()
    {
        if (started)
        {
            "The sequence is already active. [EVENT duplicate-prevented] ";
            return;
        }
        started = true;
        delayedEvent = new Fuse(self, &doorSlam, 2);
        pulseEvent = new Daemon(self, &pulse, 1);
        senseEvent = new SenseFuse(self, &ringRemoteBell, 1,
                                   remoteBell, sound);
        "The event sequence begins. [EVENT scheduled] ";
    }

    doorSlam()
    {
        delayedFired = true;
        delayedEvent = nil;
        "A distant door slams. [EVENT delayed-fired] ";
    }

    pulse()
    {
        ++pulseCount;
        "The generator sputters. [EVENT pulse=<<pulseCount>>] ";
        if (brassKey.moved && stage == 0)
        {
            stage = 1;
            "Footsteps begin beyond the wall. [EVENT stage=1] ";
        }
        else if (clue.moved && stage == 1)
        {
            stage = 2;
            "A whisper answers from the chandelier. [EVENT stage=2] ";
        }
    }

    ringRemoteBell()
    {
        bellChanged = true;
        "The iron bell rings in the stone hall. [EVENT sensory-visible] ";
        senseEvent = nil;
    }

    stopEvents()
    {
        if (delayedEvent != nil)
        {
            delayedEvent.removeEvent();
            delayedEvent = nil;
        }
        if (pulseEvent != nil)
        {
            pulseEvent.removeEvent();
            pulseEvent = nil;
        }
        if (senseEvent != nil)
        {
            senseEvent.removeEvent();
            senseEvent = nil;
        }
        started = nil;
        "The sequence stops. [EVENT canceled pulse=<<pulseCount>>] ";
    }

    noteReturn()
    {
        ++returnCount;
        "The room notices your return. [EVENT room-return=<<returnCount>>] ";
    }
;

DefineIAction(EventStatus)
    execAction()
    {
        "[EVENT status started=<<eventControl.started ? 'yes' : 'no'>>
        delayed=<<eventControl.delayedFired ? 'yes' : 'no'>>
        pulse=<<eventControl.pulseCount>> stage=<<eventControl.stage>>
        bell-state=<<eventControl.bellChanged ? 'changed' : 'unchanged'>>
        returns=<<eventControl.returnCount>>] ";
    }
    actionTime = 0
;

VerbRule(EventStatus)
    'eventstatus' : EventStatusAction
    verbPhrase = 'report/reporting event status'
;

DefineTAction(Play);

VerbRule(Play)
    ('play' | 'perform' 'on') singleDobj : PlayAction
    verbPhrase = 'play/playing (what)'
;
