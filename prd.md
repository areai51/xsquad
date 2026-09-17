

## References
pStack - /Users/vinci/xsquads_progress/references/plugins/pstack
Thermos - /Users/vinci/xsquads_progress/references/plugins/thermos


I need to build a skill called xSquad-code. the way the skill works is when you run the skill and give it a high level goal, it will have an orchestrator agent that will spawn subagents who will do the task. And the orchestrator agent ensures that the tasks are done and they're verified.

The skill needs to have the following commands

### /xSq-setup:
Th allows you to define the models for the orchestrator agent and for the sub agents. it should show the list of models available within the model list of claude code, Pi or Codex. 

### /xSq-validator-setup
We need another command called /x-validator-setup  which is very similar to the create validator script in the P stack, (which is there in the references folder.) 

### / xSq-validator-run
Runs the validators. The Orchestrator agent is constantly reusing the verification or the validator skills or tasks to verify whether a task is done and ensures that the validators are kept up to date. 

### /xSq-validator-update
Updates the validators.

### xSq-code-review
Final work product is done. The orchestrator automatically calls the code review script that does a thorough code review process. (The reference for that is the thermos or the thermonuclear scale in the references folder.) The output of the code review is sent back to the subagents to fix the review comments.
