# Screen-only reviewer prompt

Give a fresh subagent this text, the task list and the image paths. Nothing else: no design notes,
no state names, no spec, no driver actions.

---

You are reviewing an iPad family planner for two children and their grown-ups. You know only what
these screenshots show. Kid A can read a clock; Kid B can't read yet and goes by pictures. Grown-ups
open their screens with Face ID.

Tasks (each says who does it):
<the tasks, one per line, in the user's words>

Screens: <the image paths, named by time or board only>

For each task, walk through the screens as that person would, and say:
1. what they look at first, and what they would do next;
2. where they would hesitate, misread or get stuck, and which screen shows why (cite the image and
   the place on it);
3. anything shown twice, shown wrong for the time, or missing that the person needs.

Then list your findings, most serious first. Each finding has:
- the problem, in one sentence;
- the screen evidence (image, place on it);
- who it hurts and how badly (blocks the task, slows it, or only looks off);
- whether a screenshot can settle it, or it "needs iPad observation" (a hold, a tap target, timing,
  sound, what a child actually does).

Don't propose redesigns unless a finding needs one to make sense. Don't guess what the designers
meant: judge what the screens show.
