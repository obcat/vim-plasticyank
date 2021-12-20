let s:MAXCOL = get(v:, 'maxcol', 2147483647)




function plasticyank#set_operatorfunc() abort
  if mode() ==# "\<C-v>"
    set operatorfunc=s:plasticyank_operatorfunc_blockwise_visual_first_time
  else
    set operatorfunc=s:plasticyank_operatorfunc_otherwise
  endif
  return ''
endfunction




" y{characterwise-motion}
" y{linewise-motion}
" y{blockwise-motion}
" {characterwise-Visual}y
" {linewise-Visual}y
function s:plasticyank_operatorfunc_otherwise(target_text_type) abort
  " v:register may be updated by ":normal".
  let regname = v:register

  let eventignore = &eventignore
  set eventignore+=ModeChanged

  if a:target_text_type ==# 'block'
    " y{blockwise-motion}
    " {blockwise-motion} updates the "gv" range, not sure intended though.
    normal! gv
    execute printf('normal! "%sy', regname)
  else
    let v = s:visual_char_from_text_type(a:target_text_type)
    execute printf('normal! "%sy%sg`]', regname, v)
  endif

  let &eventignore = eventignore
endfunction




" {blockwise-Visual}y
function s:plasticyank_operatorfunc_blockwise_visual_first_time(target_text_type) abort
  " v:register may be updated by ":normal".
  let regname = v:register

  let eventignore = &eventignore
  set eventignore+=ModeChanged

  normal! gv
  let curswant = getcurpos()[4]
  execute printf('normal! "%sy', regname)

  let &eventignore = eventignore

  let block_height = len(getreg(regname, v:true, v:true))
  let block_width = str2nr(getregtype(regname)[1 :])
  let till_end = curswant == s:MAXCOL  " true if '$' was used

  let &operatorfunc = funcref('s:plasticyank_operatorfunc_blockwise_visual_dot_repeat', [block_height, block_width, till_end])
endfunction




" {blockwise-Visual}y -> .
function s:plasticyank_operatorfunc_blockwise_visual_dot_repeat(block_height, block_width, till_end, target_text_type) abort
  " v:register may be updated by ":normal".
  let regname = v:register

  let visual_info = s:save_visual_info()
  let eventignore = &eventignore
  set eventignore+=ModeChanged

  if match(split(&virtualedit, ','), '\C^\%(block\|all\)$') >= 0
    execute printf("normal! \<C-v>g`]\"%sy", regname)
  else

    let leftside_vcol = s:cursorcharhead_virtcol()
    let lnum_top = line("'[")  " == line('.')
    " This might cause a problem, why...
    " let lnum_bot = line("']")
    let lnum_bot = min([line('.') + a:block_height - 1, line('$')])

    if a:till_end
      for lnum in reverse(range(lnum_top, lnum_bot))
        execute lnum
        execute printf('normal! %s|', leftside_vcol)
        if s:cursorcharhead_virtcol() == leftside_vcol
          break
        endif
      endfor
      execute "normal! \<C-v>g`[$"
      execute printf('normal! "%sy', regname)
      let block_width = str2nr(getregtype(regname)[1 :])
      call setreg(regname, repeat([repeat(' ', block_width)], lnum_bot - lnum), 'ab' .. block_width)
    else
      execute printf('normal! %s|', leftside_vcol + a:block_width - 1)
      let width_top = s:cursorchartail_virtcol() - leftside_vcol + 1
      let mark_a = getpos("'a")
      normal! ma
      for lnum in reverse(range(lnum_top, lnum_bot))
        execute lnum
        execute printf('normal! %s|', leftside_vcol)
        if s:cursorcharhead_virtcol() == leftside_vcol
          break
        endif
      endfor
      execute printf('normal! %s|', leftside_vcol + a:block_width - 1)
      let width_bot = s:cursorchartail_virtcol() - leftside_vcol + 1
      if width_top < width_bot
        execute printf("normal! \"%sy\<C-v>g`[", regname)
      else
        execute printf('normal! %s|', leftside_vcol)
        execute printf("normal! \"%sy\<C-v>g`a", regname)
      endif
      call setpos("'a", mark_a)
      call setreg(regname, repeat([repeat(' ', a:block_width)], lnum_bot - lnum), 'ab' .. a:block_width)
    endif

  endif

  call s:restore_visual_info(visual_info)
  let &eventignore = eventignore
endfunction




function s:visual_char_from_text_type(text_type) abort
  if a:text_type ==# 'line'
    return 'V'
  elseif a:text_type ==# 'char'
    return 'v'
  elseif a:text_type ==# 'block'
    return "\<C-v>"
  else
    throw 'plasticyank: Internal error: Unknown text type:' .. a:text_type
  endif
endfunction




function s:save_visual_info() abort
  return {'mode': visualmode(), 'marks': [getpos("'<"), getpos("'>")]}
endfunction




function s:restore_visual_info(visual_info) abort
  if a:visual_info.mode ==# ''
    call visualmode(1)
  else
    execute 'normal!' a:visual_info.mode
    execute 'normal!' "\<Esc>"
  endif
  call setpos("'<", a:visual_info['marks'][0])
  call setpos("'>", a:visual_info['marks'][1])
endfunction




function s:cursorcharhead_virtcol() abort
  if col('.') == 1
    return 1
  else
    return virtcol([line('.'), col('.') - 1]) + 1
  endif
endfunction




function s:cursorchartail_virtcol() abort
  return virtcol('.')
endfunction
