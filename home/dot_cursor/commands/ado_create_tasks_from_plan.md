Create Azure DevOps tasks from plan file todos and link them to a parent work item.

## Instructions:

1. **Prompt for plan file path**
   - Ask user for the plan file path (relative to workspace root or absolute path)
   - If not provided, search for plan files in `.cursor/plans/` directory
   - List available plan files and let user select, or use most recent if only one
   - Plan files are markdown files with YAML frontmatter containing `todos` array

2. **Prompt for parent work item ID**
   - Ask user for the Azure DevOps work item ID to link tasks to (e.g., "1487081")
   - Validate that the work item exists by attempting to fetch it
   - If invalid, prompt again with clear error message

3. **Prompt for project** (optional)
   - Default to 'MBScrum' project
   - Allow user to override if needed
   - Use this project for all task creation operations

4. **Read and parse plan file**
   - Read the plan file content
   - Parse YAML frontmatter to extract `todos` array
   - Each todo has:
     - `id`: Unique identifier
     - `content`: Task description/content
     - `status`: Current status (may be pending, in_progress, completed, cancelled)
   - Extract plan `overview` and `plan` markdown content for context
   - Handle parsing errors gracefully with clear error messages

5. **Create Azure DevOps tasks**
   - For each todo in the `todos` array:
     - Extract title from todo content (first line, or first sentence up to 80 characters)
     - Build description:
       - Include full todo content
       - Add plan overview if available
       - Format as HTML for proper rendering in Azure DevOps
     - Create task using `mcp_Mindbody_Marketing_DataManagement-azure-devops_wit_cr9d7fd7c`:
       - project: Specified project (default 'MBScrum')
       - workItemType: 'Task'
       - fields array with:
         - System.Title: Extracted title
         - System.Description: Built description (format: 'Html')
         - System.State: 'To Do'
         - System.AreaPath: Project name (e.g., 'MBScrum')
         - System.IterationPath: Project name (e.g., 'MBScrum')
     - Track created task IDs and any failures
     - Continue creating remaining tasks even if some fail

6. **Link tasks to parent work item**
   - After all tasks are created (or as many as succeeded):
     - Use `mcp_Mindbody_Marketing_DataManagement-azure-devops_wit_woeb26227` to link tasks
     - Create batch update array with:
       - id: Created task ID
       - linkToId: Parent work item ID
       - type: 'child'
     - Link from parent's perspective: use parent work item ID as the source
     - Handle linking errors gracefully (some tasks may already be linked)
     - Note: Child links must be created from parent work item to child tasks

7. **Report results**
   - Display summary:
     - Total todos in plan
     - Successfully created tasks (with IDs and titles)
     - Failed task creations (with error messages)
     - Successfully linked tasks
     - Failed links (with error messages)
   - Format task IDs as clickable markdown links:
     - `[Task {ID}: {Title}](https://dev.azure.com/mindbody/{project}/_workitems/edit/{ID})`
   - Display parent work item link:
     - `[Parent Work Item {ID}](https://dev.azure.com/mindbody/{project}/_workitems/edit/{parentId})`

## Error Handling:

- **Missing plan file**: Prompt user again with available files listed, or exit gracefully
- **Invalid work item ID**: Validate before proceeding, prompt for correct ID
- **Azure DevOps API errors**: 
  - Log specific error messages
  - Continue with remaining tasks
  - Report partial success clearly
- **Parsing errors**: 
  - Display clear error message about what went wrong
  - Suggest checking file format
- **Partial failures**: 
  - Report which tasks succeeded and which failed
  - Provide actionable error messages
  - Allow user to retry failed operations

## Context:

- Default project: 'MBScrum'
- Task work item type: 'Task'
- Default state: 'To Do'
- Link type: 'child' (hierarchy relationship)

## Important Notes:

- Plan files use YAML frontmatter with `todos` array
- Task titles should be concise (first line or first sentence)
- Descriptions should include full context (todo content + plan overview)
- Child links must be created from parent work item to children (not reverse)
- Batch operations may fail partially - handle gracefully
- Always provide clear feedback on what succeeded and what failed
- Format all Azure DevOps URLs as clickable markdown links
