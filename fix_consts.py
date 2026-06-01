import os
import re

directory = 'lib'
patterns = [
    (r'const\s+(Icon\([^)]*color:\s*AppColors\.(textHint|textPrimary|textSecondary|surface|background|cardBg|border|divider)[^)]*\))', r'\1'),
    (r'const\s+(Divider\([^)]*color:\s*AppColors\.(textHint|textPrimary|textSecondary|surface|background|cardBg|border|divider)[^)]*\))', r'\1'),
    (r'const\s+(BorderSide\([^)]*color:\s*AppColors\.(textHint|textPrimary|textSecondary|surface|background|cardBg|border|divider)[^)]*\))', r'\1'),
    (r'const\s+(FlLine\([^)]*color:\s*AppColors\.(textHint|textPrimary|textSecondary|surface|background|cardBg|border|divider)[^)]*\))', r'\1'),
    (r'const\s+(Text\([^)]*color:\s*AppColors\.(textHint|textPrimary|textSecondary|surface|background|cardBg|border|divider)[^)]*\))', r'\1'),
    (r'const\s+style\s*=\s*(TextStyle\([^)]*color:\s*AppColors\.(textHint|textPrimary|textSecondary|surface|background|cardBg|border|divider)[^)]*\))', r'final style = \1'),
    (r'const\s+(BoxDecoration\([^)]*color:\s*AppColors\.(textHint|textPrimary|textSecondary|surface|background|cardBg|border|divider)[^)]*\))', r'\1')
]

for root, _, files in os.walk(directory):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r') as f:
                content = f.read()
            
            original_content = content
            for pattern, repl in patterns:
                content = re.sub(pattern, repl, content)
            
            if content != original_content:
                with open(filepath, 'w') as f:
                    f.write(content)
                print(f"Fixed {filepath}")
