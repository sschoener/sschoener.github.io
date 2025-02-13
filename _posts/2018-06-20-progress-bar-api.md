---
layout: post
title: (D)Evolution of a Progress Bar
excerpt: In which I rant about the evolution of a progress bar class in a code base I am involved in
tags: [computer science, programming]
---

At work, I am currently contributing to a code base for a game that is very much UI driven. At some point, someone has the clever idea of abstracting common patterns and creates a class for a progress bar. The progress bar consists of a bar filling up plus a label that displays the progress in some way.

The first version that I can find in git is this here (C# code, not mine):
```csharp
public class ProgressBar : MonoBehaviour {
	[SerializeField]
	private RectTransform _progressBar;

    // The UI label
	[SerializeField]
	private TMP_Text _progressText;

    // A suffix that is added to the progress bar text, can be configured from the outside in the Unity Editor
	[SerializeField]
	private string _progressTextSuffix = "";

    // Whether the progress text should count down
	public bool CountDown {get; set;}

	private float _progressBarLength;
    // for some reason, the progress is saved but not really used across calls
	private float _progress;
	private float _maxProgress = 1f;

	public void Initialize() {
		_progressBarLength = _progressBar.sizeDelta.x;
	}

    // Sets the progress to a normalized value
	public void SetProgress(float progress) {
		_progress = Mathf.Clamp01(progress);
		_progressBar.sizeDelta = new Vector2 (
			Mathf.Lerp(0f, _progressBarLength, _progress),
			_progressBar.sizeDelta.y
		);
		if (CountDown) {
			_progressText.text =
				Mathf.Lerp(0f, _maxProgress, 1f - _progress).ToString("0.00") +
				_progressTextSuffix;
		} else {
			_progressText.text =
				Mathf.Lerp(0f, _maxProgress, _progress).ToString("0.00") +
				_progressTextSuffix;
		}
	}

    // Sets the maximum progress value, only used visually
	public void SetMaxProgressValue(float maxProgress) {
		_maxProgress = maxProgress;
	}
}
```

The comments are mine; the code base is very light on documentation. The first thing that springs to my mind is that the way that the class is configured is very heterogeneous: There's `CountDown` (set through a property), there's `_maxProgress` (set through a public function), and `_progressTextSuffix` (set in the Unity editor). I dislike this choice greatly, but it is more down to consistency than actual usability. There are some Unity related issues in there as well (I think that using `sizeDelta` here is just not right), but we'll ignore them for now.

A few weeks later, I found a commit that added a method to the class:
```csharp
	public void SetProgressValues(int currentAmount, int maxAmount) {
		_progress = Mathf.Clamp01((float)currentAmount/(float)maxAmount);
		_progressMask.fillAmount = _progress;
		_progressText.text = currentAmount + "/" + maxAmount;
	}
```
There is no code-review process and there are no merge-requests for the code base, so you generally only see other people's changes once they come up in the main branch you are working on (in case you did not notice it, I despise that system and consider it defunct). What's wrong with this new method? Well, it breaks the class in many ways:
 * it ignores the `CountDown` flag,
 * it ignnores the `_progressTextSuffix` string,
 * it ignores the `_maxProgress` field,
 * its interface departs from the existing `SetProgress`,
 * and it is poorly named.
Effectively, it makes it much more difficult to use the class correctly. None of the options of the configuration options of the class work with this method! Introducing this new method has therefore introduced states that must be considered invalid.

Why do changes like this happen? Well, whoever implemented it didn't need any of the other functionality, so they ignored it. Great, that's what good software engineering is all about.

How can we fix it? I think there are two strategies here: Usually I'd say that whenever you add a new feature to a class, you should rather ask whether you should maybe create a new class entirely (following the idea that a class should only have a single purpose). I met some resistance with this proposal (and understandably so) and decided to clean it up a bit, replacing the methods with this:

```csharp
	/// <summary>
	/// Sets the progress to a value between 0 and the maximum progress value.
	/// </summary>
	public void SetProgress(float progress, float maxProgress) {
		float normalizedProgress = Mathf.Clamp01(progress / maxProgress);
		_progressMask.fillAmount = normalizedProgress;
		float textValue = CountDown ? 1 - normalizedProgress : normalizedProgress;
		_progressText.text = Mathf.Lerp(0f, maxProgress, textValue).ToString("00 ") + _progressTextSuffix;
	}

	/// <summary>
	/// Sets the value of this progress bar as a counter. This means that it will display
	/// the progress as a discrete count, e.g. 3 / 5 for 3 out of 5.
	/// </summary>
	public void SetCounter(int currentAmount, int maxAmount) {
		float normalizedProgress = Mathf.Clamp01((float)currentAmount/(float)maxAmount);
		_progressMask.fillAmount = normalizedProgress;
		int textValue = CountDown ? maxAmount - currentAmount : currentAmount;
		_progressText.text = textValue + "/" + maxAmount + _progressTextSuffix;
	}
```

Note in particular that
 * all options work for each case,
 * the interface is uniform -- both methods take their maximum progress.


A week later, as it was bound to happen, someone somewhere decided that not *all* progress bars will have a text, so `_progressText` should also allowed to be null. To their credit, they introduced that check in both methods. Unfortunately, someone else was working on the same class at the same time but on a different branch and merged carelessly, yielding the following set of methods:

```csharp
	/// <summary>
	/// Sets the progress to a value between 0 and the maximum progress value.
	/// </summary>
	public void SetProgress(float progress, float maxProgress) {
		float normalizedProgress = Mathf.Clamp01(progress / maxProgress);
		_progressMask.fillAmount = normalizedProgress;
		float textValue = CountDown ? 1 - normalizedProgress : normalizedProgress;
        if (_progressText != null)
		    _progressText.text = Mathf.Lerp(0f, maxProgress, textValue).ToString("00 ") + _progressTextSuffix;
	}

	/// <summary>
	/// Sets the value of this progress bar as a counter. This means that it will display
	/// the progress as a discrete count, e.g. 3 / 5 for 3 out of 5.
	/// </summary>
	public void SetCounter(int currentAmount, int maxAmount) {
		float normalizedProgress = Mathf.Clamp01((float)currentAmount/(float)maxAmount);
		_progressMask.fillAmount = normalizedProgress;
		int textValue = CountDown ? maxAmount - currentAmount : currentAmount;
        if (_progressText != null)
		    _progressText.text = textValue + "/" + maxAmount + _progressTextSuffix;
	}

	/// <summary>
	/// Sets the progress to a value between 0 and the maximum progress value.
	/// </summary>
	/// <param name="time"></param>
	public void SetTime(float currentTime, float duration) {
		if (currentTime == 0f && duration == 0f) {
			_progressText.text = string.Empty;
			_progressMask.fillAmount = 0;
		} else {
			float normalizedProgress = Mathf.Clamp01(currentTime / duration);
			_progressMask.fillAmount = normalizedProgress;
			float textValue = CountDown ? 1 - normalizedProgress : normalizedProgress;
			float timevalue = Mathf.Lerp(0f, duration, textValue);
			int minutes = Mathf.FloorToInt(timevalue / 60F);
			int seconds = Mathf.FloorToInt(timevalue - minutes * 60);
			_progressText.text = string.Format("<mspace=2em>{0:00}<mspace=1em>:<mspace=2em>{1:00}", minutes, seconds) + _progressTextSuffix;
		}
	}
```
Phew. Now this version is entirely undecided whether it requires `_progressText` to not be `null`. The new `SetTime` function (that shamelessly copied over my comment without changing it) also introduces yet more problem. First of all, its parameter naming is questionable (given that `currentTime` could also stand for the absolute time in the game), but more importantly, it assumes that its input values are specified in seconds and its output is formatted as `minutes:seconds`. This likely means that the `_progressTextSuffix` should be empty. Interestingly, the commit author only added the suffix handling in an additional commit, most likely because I sat down with them for a long talk about invalid configurations about the class.

Today, there was yet another update to the progress bar class. It adds a field called `_leftToRight` that can be configured from Unity's editor. The only other piece of the class that was edited is this here:
```csharp
	public void SetProgress(float progress, float maxProgress) {
		float normalizedProgress = Mathf.Clamp01(progress / maxProgress);
        _progressMask.fillOrigin = (int)(_leftToRight?Image.OriginHorizontal.Right:Image.OriginHorizontal.Left); // new!
		_progressMask.fillAmount = normalizedProgress;
		float textValue = CountDown ? 1 - normalizedProgress : normalizedProgress;
        if (_progressText != null)
		    _progressText.text = Mathf.Lerp(0f, maxProgress, textValue).ToString("00 ") + _progressTextSuffix;
	}
```
I probably don't have to point out that this means that both other methods for setting the progress are now broken because they ignore this flag. I spent 5 minutes of my life today wondering why it doesn't work only to notice that yet again someone managed to break something as simple as a progress bar. If you look closely, you will also see that the `_leftToRight` flag should actually be called `_rightToLeft`.

At this point, I'm left wondering what could be done to make sure that this class doesn't have to suffer any more. In all honesty, it's not just this class, but every other class in the codebase. The mentality of *oh, I'll just add this feature over here where I need it* without considering any of the consequences is something that I'd really like to eradicate (mostly because it would save me the time of cleaning all of this up all the time).