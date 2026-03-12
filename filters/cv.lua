local function trim_inlines(inlines)
  local first = 1
  local last = #inlines

  while first <= last and (inlines[first].t == "Space" or inlines[first].t == "SoftBreak") do
    first = first + 1
  end

  while last >= first and (inlines[last].t == "Space" or inlines[last].t == "SoftBreak") do
    last = last - 1
  end

  local trimmed = {}
  for i = first, last do
    trimmed[#trimmed + 1] = inlines[i]
  end
  return trimmed
end

local function split_on_last_pipe(inlines)
  local pipe_index = nil

  for i, inline in ipairs(inlines) do
    if inline.t == "Str" and inline.text == "|" then
      pipe_index = i
    end
  end

  if pipe_index == nil then
    return nil
  end

  local left = {}
  local right = {}

  for i, inline in ipairs(inlines) do
    if i < pipe_index then
      left[#left + 1] = inline
    elseif i > pipe_index then
      right[#right + 1] = inline
    end
  end

  return trim_inlines(left), trim_inlines(right)
end

local function latex_escape(text)
  local escaped = text
  escaped = escaped:gsub("\\", "\\textbackslash{}")
  escaped = escaped:gsub("([{}%%#&_])", "\\%1")
  escaped = escaped:gsub("%$", "\\$")
  escaped = escaped:gsub("%^", "\\textasciicircum{}")
  escaped = escaped:gsub("~", "\\textasciitilde{}")
  return escaped
end

local function latex_of_inlines(inlines)
  local doc = pandoc.Pandoc({ pandoc.Plain(inlines) }, pandoc.Meta({}))
  local latex = pandoc.write(doc, "latex")
  latex = latex:gsub("^%s+", "")
  latex = latex:gsub("%s+$", "")
  latex = latex:gsub("\n", " ")
  return latex
end

local function latex_of_blocks(blocks)
  local doc = pandoc.Pandoc(blocks, pandoc.Meta({}))
  local latex = pandoc.write(doc, "latex")
  latex = latex:gsub("^%s+", "")
  latex = latex:gsub("%s+$", "")
  return latex
end

local function meta_string(meta, group, key)
  if meta[group] == nil or meta[group][key] == nil then
    return ""
  end
  return pandoc.utils.stringify(meta[group][key])
end

local function meta_list(meta, group, key)
  local result = {}
  if meta[group] == nil or meta[group][key] == nil then
    return result
  end

  local value = meta[group][key]
  if value.t == "MetaList" or (#value > 0) then
    for _, item in ipairs(value) do
      result[#result + 1] = pandoc.utils.stringify(item)
    end
  else
    result[#result + 1] = pandoc.utils.stringify(value)
  end

  return result
end

local function transform_header(el)
  if el.level == 1 then
    return pandoc.RawBlock("latex", "\\cvsection{" .. latex_of_inlines(el.content) .. "}")
  end

  if el.level == 2 or el.level == 3 then
    local left, right = split_on_last_pipe(el.content)
    if left == nil then
      return nil
    end

    local macro = el.level == 2 and "\\cvcompany" or "\\cvposition"
    return pandoc.RawBlock("latex", macro .. "{" .. latex_of_inlines(left) .. "}{" .. latex_of_inlines(right) .. "}")
  end

  return nil
end

local function transform_bullet_list(el, compact)
  local env = compact and "cvitemscompact" or "cvitems"
  local lines = { "\\begin{" .. env .. "}" }

  for _, item in ipairs(el.content) do
    local latex = latex_of_blocks(item)
    latex = latex:gsub("^%s+", "")
    latex = latex:gsub("%s+$", "")
    latex = latex:gsub("\n+", " ")
    lines[#lines + 1] = "\\item " .. latex
  end

  lines[#lines + 1] = "\\end{" .. env .. "}"
  return pandoc.RawBlock("latex", table.concat(lines, "\n"))
end

function Pandoc(doc)
  local doc_type = meta_string(doc.meta, "document", "type")

  local cv_header = "\\cvheader{" ..
    latex_escape(meta_string(doc.meta, "cv", "name")) .. "}{" ..
    latex_escape(meta_string(doc.meta, "cv", "availability")) .. "}{" ..
    latex_escape(meta_string(doc.meta, "cv", "phone")) .. "}{" ..
    latex_escape(meta_string(doc.meta, "cv", "email")) .. "}{" ..
    latex_escape(meta_string(doc.meta, "cv", "location")) .. "}"

  local motivation_header = "\\motivationheader{" ..
    latex_escape(meta_string(doc.meta, "cv", "name")) .. "}{" ..
    latex_escape(meta_string(doc.meta, "cv", "phone")) .. "}{" ..
    latex_escape(meta_string(doc.meta, "cv", "email")) .. "}{" ..
    latex_escape(meta_string(doc.meta, "cv", "location")) .. "}"

  local linkedin = meta_string(doc.meta, "cv", "linkedin")
  local footer = "\\linkedinline{LinkedIn: \\href{" .. latex_escape(linkedin) .. "}{" .. latex_escape(linkedin) .. "}}"

  local blocks = {
    pandoc.RawBlock("latex", doc_type == "motivation" and motivation_header or cv_header)
  }

  if doc_type == "motivation" then
    local letter_title = meta_string(doc.meta, "letter", "title")
    local letter_date = meta_string(doc.meta, "letter", "date")
    local recipient = meta_list(doc.meta, "letter", "recipient")

    blocks[#blocks + 1] = pandoc.RawBlock("latex", "\\letterheading{" .. latex_escape(letter_title) .. "}{" .. latex_escape(letter_date) .. "}")
    if #recipient > 0 then
      blocks[#blocks + 1] = pandoc.RawBlock("latex", "\\begin{recipientblock}")
      for _, line in ipairs(recipient) do
        blocks[#blocks + 1] = pandoc.RawBlock("latex", "\\recipientline{" .. latex_escape(line) .. "}")
      end
      blocks[#blocks + 1] = pandoc.RawBlock("latex", "\\end{recipientblock}")
    end

    local body = doc.blocks
    if #body > 0 and body[1].t == "Header" and body[1].level == 1 then
      table.remove(body, 1)
    end
    blocks[#blocks + 1] = pandoc.RawBlock("latex", "\\begin{motivationbody}")
    for _, block in ipairs(body) do
      blocks[#blocks + 1] = block
    end
    blocks[#blocks + 1] = pandoc.RawBlock("latex", "\\end{motivationbody}")
  else
    local source_blocks = doc.blocks

    for i, block in ipairs(source_blocks) do
      if block.t == "Header" then
        local converted = transform_header(block)
        blocks[#blocks + 1] = converted or block
      elseif block.t == "BulletList" then
        local next_block = source_blocks[i + 1]
        local compact = next_block ~= nil and next_block.t == "Header" and next_block.level == 3
        blocks[#blocks + 1] = transform_bullet_list(block, compact)
      else
        blocks[#blocks + 1] = block
      end
    end

    blocks[#blocks + 1] = pandoc.RawBlock("latex", footer)
  end

  return pandoc.Pandoc(blocks, doc.meta)
end
