import os
import sys
import yaml

def md_to_yaml(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        md_content = f.read()
    data = {"markdown_content": md_content}

    base, _ = os.path.splitext(file_path)
    yaml_path = base + ".yaml"
    with open(yaml_path, "w", encoding="utf-8") as f:
        yaml.dump(data, f, sort_keys=False, allow_unicode=True)
    print(f"Converted {file_path} → {yaml_path}")

def yaml_to_md(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)

    base, _ = os.path.splitext(file_path)
    md_path = base + ".md"

    # If structured YAML, try to output nicely; if just markdown_content, unwrap it
    if isinstance(data, dict) and "markdown_content" in data:
        md_content = data["markdown_content"]
    else:
        md_content = yaml.dump(data, sort_keys=False, allow_unicode=True)

    with open(md_path, "w", encoding="utf-8") as f:
        f.write(md_content)
    print(f"Converted {file_path} → {md_path}")

def main():
    if len(sys.argv) < 2:
        print("Usage: python md_yaml_converter.py <file.md | file.yaml>")
        return

    file_path = sys.argv[1]
    if not os.path.exists(file_path):
        print(f"Error: File not found: {file_path}")
        return

    if file_path.endswith(".md"):
        md_to_yaml(file_path)
    elif file_path.endswith(".yaml") or file_path.endswith(".yml"):
        yaml_to_md(file_path)
    else:
        print("Error: Input must be .md or .yaml file")

if __name__ == "__main__":
    main()
