# Detection Run Template

## Instructions

1. Read `{detector_path}` to understand the detection methodology and analysis approach.
2. Read `{test_agent_path}` to load the target agent definition to be analyzed.
3. Follow the detector's analysis instructions exactly. The target is:
   - `{agent_path}` = `{test_agent_path}`
   - `{agent_name}` = `{agent_name}`
   - `{findings_save_path}` = `{findings_save_path}`
4. Save findings to `{findings_save_path}` in the format specified by the detector.
5. Return ONLY the summary line as specified by the detector's Return Format section.
