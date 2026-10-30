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
    showIntro() { "Standard adv3 validation fixture. [VALIDATION intro] "; }
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
    "The device's pointer is <<isAligned ? 'aligned' : 'off center'>>.
    [VALIDATION state=<<isAligned ? 'aligned' : 'unaligned'>>] "
    isAligned = nil

    dobjFor(Align)
    {
        verify() { logical; }
        check()
        {
            if (isAligned)
                failCheck('The device is already aligned.
                    [VALIDATION duplicate-action=blocked] ');
        }
        action()
        {
            isAligned = true;
            alignmentAward.awardPointsOnce();
            "You align the demonstration device.
            [VALIDATION action=aligned award=5] ";
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
        ? 'The caretaker says the reading is now correct.
            [VALIDATION conversation=aligned]'
        : 'The caretaker says the pointer needs alignment.
            [VALIDATION conversation=unaligned]'>>"
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
            "A quiet mechanism clicks once.
            [VALIDATION event=clockwork-fired] ";
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
        "DEBUG STATUS: aligned=<<sampleDevice.isAligned ? 'true' : 'nil'>>.
        [VALIDATION debug-command=accepted] ";
    }
    actionTime = 0
;

VerbRule(DebugStatus)
    'debugstatus'
    : DebugStatusAction
    verbPhrase = 'show/showing debug status'
;
#endif

DefineIAction(ValidationScore)
    execAction()
    {
        "[VALIDATION score=<<libScore.totalScore>>] ";
    }
    actionTime = 0
;

VerbRule(ValidationScore)
    'validationscore'
    : ValidationScoreAction
    verbPhrase = 'report/reporting validation score'
;
