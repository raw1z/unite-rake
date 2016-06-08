" Variables {{{
let s:Vital = vital#of('vital')
let s:Prelude = s:Vital.import('Prelude')
let s:Filepath = s:Vital.import('System.Filepath')
let s:String = s:Vital.import('Data.String')
let s:List = s:Vital.import('Data.List')
"}}}

function! unite#sources#rake#define() abort "{{{
  return s:source
endfunction "}}}

let s:source = {
      \ 'name' : 'rake',
      \ 'description' : 'list rake tasks',
      \ 'default_kind' : 'command',
      \ 'hooks' : {},
      \}

let s:job = {'pty': 1, 'TERM': 'xterm-256color'} "{{{
function s:job.parse_data(data) "{{{
  let lines = []
  for item in a:data
    let lines = s:List.conj(lines, item)
  endfor

  return join(lines, "\n")
endfunction "}}}
function s:job.on_stdout(job_id, data) "{{{
  let self.stdout = self.stdout . self.parse_data(a:data)
endfunction "}}}
function s:job.on_stderr(job_id, data) "{{{
  let self.stderr = self.stderr . self.parse_data(a:data)
endfunction "}}}
function s:job.on_exit(job_id, data) "{{{
  let self.exited = 1
endfunction "}}}
function s:job.read_lines() "{{{
  let stdout_lines = self.read_lines_from_stream(self.stdout)
  let self.stdout = ''

  let stderr_lines = self.read_lines_from_stream(self.stderr)
  let self.stderr = ''

  return s:List.concat([stdout_lines, stderr_lines])
endfunction "}}}
function s:job.read_lines_from_stream(stream) "{{{
  return s:String.lines(a:stream)
endfunction "}}}
function s:job.new() "{{{
  let instance = extend(copy(self), {'stdout': '', 'stderr': '', 'exited': 0})
  let command = ['./bin/rake', '--tasks', '--all']
  let instance.id = jobstart(command, instance)
  return instance
endfunction "}}}
"}}}
function! s:source.gather_candidates(args, context) abort "{{{
  if a:context.is_redraw
    let a:context.is_async = 1
  endif

  if a:context.is_redraw
    let a:context.is_async = 1
  endif

  try
    let a:context.source__job = s:job.new()
  catch
    call unite#print_error(v:exception)
    let a:context.is_async = 0
    return []
  endtry

  return self.async_gather_candidates(a:args, a:context)
endfunction "}}}
function! s:source.async_gather_candidates(args, context) abort "{{{
  let job = a:context.source__job

  if job.exited
    let a:context.is_async = 0
    call jobwait([job.id])
  endif

  let tasks_data = map(job.read_lines(), "self.parse_line(v:val)")

  let candidates = map(tasks_data, "{
        \ 'word' : v:val.task,
        \ 'abbr' : unite#util#truncate(v:val.task, 60) .
        \         (v:val.description != '' ? ' -- ' . v:val.description : ''),
        \ 'action__command' : self.run_rake_task(v:val.task)
        \ }")

  return candidates
endfunction "}}}
function! s:source.hooks.on_close(args, context) abort "{{{
  if has_key(a:context, 'source__job')
    let job = a:context.source__job
    if job.exited == 0
      call jobstop(job.id)
    endif
  endif
endfunction "}}}
function! s:source.parse_line(data) abort "{{{
  let sanitizedData = s:String.replace_first(a:data, "rake", '')
  let tokens = s:String.nsplit(sanitizedData, 2, '#')
  let tokens = map(tokens, "s:String.trim(v:val)")
  let tokens = map(tokens, "s:String.chomp(v:val)")
  return {
        \ 'task': tokens[0],
        \ 'description': tokens[1],
        \ }
endfunction "}}}
function! s:source.run_rake_task(data) abort "{{{
  let sanitizedStr = s:String.replace(a:data, ":", '\:')
  return "Unite -multi-line output/shellcmd:rake\\ " . sanitizedStr
endfunction "}}}

