#include <adv3.h>
#include <en_us.h>

versionInfo: GameID
    name = 'adv3 Skill Validation'
    byline = 'by the validation fixture'
    htmlByline = 'by the validation fixture'
    version = '1'
    authorEmail = 'nobody@example.invalid'
    desc = 'A neutral standard-adv3 validation fixture.'
;

gameMain: GameMainDef
    initialPlayerChar = me
    showIntro() { "Standard adv3 validation fixture. "; }
;

workroom: Room 'Demonstration Room'
    "A plain workroom contains a calibration pedestal. A caretaker waits nearby. "
;

me: Actor
    location = workroom
;

alignmentAward: Achievement
    points = 5
    desc = 'aligning the demonstration device'
;

sampleDevice: Fixture 'brass sample demonstration device' 'demonstration device'
    @workroom
    "The device's pointer is <<isAligned ? 'aligned' : 'off center'>>. "
    isAligned = nil

    dobjFor(Align)
    {
        verify() { logical; }
        check()
        {
            if (isAligned)
                failCheck('The device is already aligned. ');
        }
        action()
        {
            isAligned = true;
            alignmentAward.awardPointsOnce();
            "You align the demonstration device. ";
        }
    }
;

DefineTAction(Align);

VerbRule(Align)
    ('align' | 'calibrate') singleDobj
    : AlignAction
    verbPhrase = 'align/aligning (what)'
;

caretaker: Actor 'patient caretaker' 'caretaker' @workroom
    "The caretaker watches the demonstration. "
;

+ AskTellTopic @sampleDevice
    "<<sampleDevice.isAligned
        ? 'The caretaker says the reading is now correct.'
        : 'The caretaker says the pointer needs alignment.'>>"
;

+ DefaultAskTellTopic
    "The caretaker has nothing to add about that. "
;

clockwork: Fixture 'quiet clockwork mechanism' 'clockwork mechanism' @workroom
    tickCount = 0
    tick()
    {
        ++tickCount;
        if (tickCount == 2)
            "A quiet mechanism clicks once. ";
    }
;

eventStarter: InitObject
    execute()
    {
        new Daemon(clockwork, &tick, 1);
    }
;

#ifdef __DEBUG
DefineIAction(DebugStatus)
    execAction()
    {
        "DEBUG STATUS: aligned=<<sampleDevice.isAligned>>. ";
    }
    actionTime = 0
;

VerbRule(DebugStatus)
    'debugstatus'
    : DebugStatusAction
    verbPhrase = 'show/showing debug status'
;
#endif
