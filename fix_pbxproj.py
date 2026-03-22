import sys

file_path = "/Users/jcalles/github/PortfolioMultiplatform/PortfolioMultiplatform.xcodeproj/project.pbxproj"
with open(file_path, "r") as f:
    content = f.read()

# Replace MARKETING_VERSION = 1.0.4.1.1; with MARKETING_VERSION = 1.0.4;
content = content.replace("MARKETING_VERSION = 1.0.4.1.1;", "MARKETING_VERSION = 1.0.4;")
content = content.replace("MARKETING_VERSION = 1.0.4.1;", "MARKETING_VERSION = 1.0.4;")

# Add App Category to PortfolioRefreshLoginItem build settings
debug_block_target = "Default.xcconfigMACOSX_DEPLOYMENT_TARGET = 15.0;"
				MARKETING_VERSION = 1.0.4;"""
debug_block_replacement = """INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.finance";
				MACOSX_DEPLOYMENT_TARGET = 15.0;
				MARKETING_VERSION = 1.0.4;"""

content = content.replace(debug_block_target, debug_block_replacement)

with open(file_path, "w") as f:
    f.write(content)
print("Project file updated successfully.")
