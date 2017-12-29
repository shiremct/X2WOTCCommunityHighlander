//-----------------------------------------------------------
// Used by the visualizer system to control a Visualization Actor.
//-----------------------------------------------------------
class X2Action_AbilityPerkDurationEnd extends X2Action
	dependson(XComAnimNodeBlendDynamic);

var private XGUnit TrackUnit;

var private XGUnit CasterUnit;
var private XGUnit TargetUnit;
var private XComUnitPawnNativeBase CasterPawn;

// *******************************
// Start Issue #142 (Part 1 of 4):
// Added EndingPerks array variable to support removing multiple perk content instances attached to a single effect state.
// Updated references, using the existing EndingPerk single instance variable to iterate through the array to reduce code differences.

var private array<XComPerkContentInst> EndingPerks;
var private XComPerkContentInst EndingPerk;

// End Issue #142
// *******************************

var private CustomAnimParams AnimParams;
var private int x, i;

var XComGameState_Effect EndingEffectState;

function Init()
{
	local X2Effect EndingEffect;
	local name EndingEffectName;
	//local array<XComPerkContentInst> Perks;
	local bool bIsCasterTarget;

	super.Init();

	TrackUnit = XGUnit( Metadata.VisualizeActor );

	EndingEffect = class'X2Effect'.static.GetX2Effect( EndingEffectState.ApplyEffectParameters.EffectRef );
	if (X2Effect_Persistent(EndingEffect) != none)
	{
		EndingEffectName = X2Effect_Persistent(EndingEffect).EffectName;
	}
	`assert( EndingEffectName != '' ); // what case isn't being handled?

	CasterUnit = XGUnit( `XCOMHISTORY.GetVisualizer( EndingEffectState.ApplyEffectParameters.SourceStateObjectRef.ObjectID ) );
	if (CasterUnit == none)
		CasterUnit = TrackUnit;

	CasterPawn = CasterUnit.GetPawn( );

	TargetUnit = XGUnit( `XCOMHISTORY.GetVisualizer( EndingEffectState.ApplyEffectParameters.TargetStateObjectRef.ObjectID ) );

	// *******************************
	// Start Issue #142 (Part 2 of 4):
	// Change function call to the plural GetAssociatedDurationPerkInstances function that returns an array of ALL perk content
	// instances attached to the effect state (rather than just the first one found).

	class'XComPerkContent'.static.GetAssociatedDurationPerkInstances( EndingPerks, CasterPawn, EndingEffectState );
	
	// Change logic to flag the caster as the target - previous code doesn't work with the array and is unneccesary anyway

	if (EndingPerks.Length > 0)
	{
		bIsCasterTarget = (TargetUnit == CasterUnit);
	}
	
	// End Issue #142
	// *******************************
}

event bool BlocksAbilityActivation()
{
	return false;
}

//------------------------------------------------------------------------------------------------
simulated state Executing
{

	simulated event BeginState(Name PreviousStateName)
	{
		// *******************************
		// Start Issue #142 (Part 3 of 4):
		// Restructure event to handle multiple perk content instances in the array.
		
		if (EndingPerks.Length > 0)
		{
			Foreach EndingPerks(EndingPerk)
			{
				if ((TargetUnit != None) && (TargetUnit != CasterUnit))
				{
					EndingPerk.RemovePerkTarget( TargetUnit );
				}
				else
				{
					EndingPerk.OnPerkDurationEnd( );
				}
			}
		}
		
		// End Issue #142
		// *******************************
	}

Begin:

	// *******************************
	// Start Issue #142 (Part 4 of 4):
	// Wrap perk content removal code in a For loop to handle all members of the EndingPerks array (Foreach loop didn't work).
	// Change all EndingPerk references to EndingPerks[i] to pull from the array.
	
	if (EndingPerks.Length > 0)
	{
		for ( i = 0; i < EndingPerks.Length; i ++ )
		{
			AnimParams.AnimName = class'XComPerkContent'.static.ChooseAnimationForCover( CasterUnit, EndingPerks[i].m_PerkData.CasterDurationEndedAnim );
			AnimParams.PlayRate = GetNonCriticalAnimationSpeed();

			if ((EndingPerks[i].m_ActiveTargetCount == 0) && EndingPerks[i].m_PerkData.CasterDurationEndedAnim.PlayAnimation && AnimParams.AnimName != '')
			{
				if( EndingPerks[i].m_PerkData.CasterDurationEndedAnim.AdditiveAnim )
				{
					FinishAnim(CasterPawn.GetAnimTreeController().PlayAdditiveDynamicAnim(AnimParams));
					CasterPawn.GetAnimTreeController().RemoveAdditiveDynamicAnim(AnimParams);
				}
				else
				{
					FinishAnim(CasterPawn.GetAnimTreeController().PlayFullBodyDynamicAnim(AnimParams));
				}
			}

			if (EndingPerks[i].m_PerkData.TargetDurationEndedAnim.PlayAnimation)
			{
				AnimParams.AnimName = class'XComPerkContent'.static.ChooseAnimationForCover( TargetUnit, EndingPerks[i].m_PerkData.TargetDurationEndedAnim );
				if (AnimParams.AnimName != '')
				{
					if( EndingPerks[i].m_PerkData.CasterDurationEndedAnim.AdditiveAnim )
					{
						FinishAnim(TargetUnit.GetPawn().GetAnimTreeController().PlayAdditiveDynamicAnim(AnimParams));
						TargetUnit.GetPawn().GetAnimTreeController().RemoveAdditiveDynamicAnim(AnimParams);
					}
					else
					{
						FinishAnim(TargetUnit.GetPawn().GetAnimTreeController().PlayFullBodyDynamicAnim(AnimParams));
					}
				}
			}
		}
	}
	
	// End Issue #142
	// *******************************

	CompleteAction();
}

