@if (0)==(0) echo off
cscript.exe //nologo //E:JScript "%~f0" %*
exit /B %ERRORLEVEL%
@end

var fs = WScript.CreateObject("Scripting.FileSystemObject");
var sh = WScript.CreateObject("WScript.Shell");
var eu = sh.Environment("Process");

String.prototype.trim    = function ()  {return this.replace(/^\s+|\s+$/g, "");};
String.prototype.trimEnd = function ()  {return this.replace(/\s+$/g,      "");};
Array.prototype.map      = function (f) {var xs = []; for(var i = 0; i < this.length; i++) {xs.push(f(this[i]));} return(xs);};

var opt  = {print : false, just_print : false, always_make : false};
var args = [];
for(var i = 0; i < WScript.Arguments.Length; i++)
{
	var arg = WScript.Arguments(i);
	if     (arg == "-p") {opt.print       = true;}
	else if(arg == "-n") {opt.just_print  = true;}
	else if(arg == "-B") {opt.always_make = true;}
	else
	{
		args.push(arg);
	}
}

var make = parse("Makefile");
if(args.length == 0) {args.push(make.$START);}
for(var i = 0; i < args.length; i++)
{
	run(make, args[i]);
}
WScript.Quit(0);

function parse(makefile, env)
{
	if(!env)
	{
		env = this;
		
		env.$ENV     = {};
		env.$START   = "";
		env.$TARGET  = {};
		env.$PHONY   = [];
		env.set_val = function (key, s)
			{
				env.$ENV[key] = s;
				eu.Item(key) = s;
			};
		env.get_val = function (s)
			{
				if(s in env.$ENV) {return(env.$ENV[s]);}
				
				var key   = "%" + s + "%";
				var value = sh.ExpandEnvironmentStrings(key);
				return(value == key && sh.Environment("SYSTEM")(s) == "" ? "" : value);
			};
	}
	
	
	var f = fs.OpenTextFile(makefile);
	try
	{
		/*
			ifeq "$(xxx)" "xxx"
				command
			else
				command
			endif
		*/
		
		var target  = "";
		var linenum = 0;
		var parse_line = function (line)
			{
				var comment_index = line.indexOf("#");
				if(comment_index >= 0) {line = line.substring(0, comment_index);}
				
				if(line.length == 0) {target = ""; return;}
				
				if(line.substring(0, 1) == "\t")
				{
					if(target == "") {throw new Error("parse error, none target(" + linenum + ")");}
					env.$TARGET[target].commands.push(line.replace(/^\t+/, ""));
				}
				else
				{
					target = "";
					var set_index    = line.indexOf(":=");
					var expand_index = line.indexOf("=");
					var target_index = line.indexOf(":");
					
					if(set_index >= 0 && (set_index <= expand_index && set_index <= target_index))
					{
						var key   = line.substring(0, set_index).trim();
						var value = line.substring(set_index + 2).trim();
						
						env.set_val(key, expand(env, value).value);
					}
					else if(expand_index >= 0 && (target_index < 0 || expand_index < target_index))
					{
						var key   = line.substring(0, expand_index).trim();
						var value = line.substring(expand_index + 1).trim();
						
						env.set_val(key, value);
					}
					else if(target_index >= 0 && (expand_index < 0 || expand_index > target_index))
					{
						target = line.substring(0, target_index).trim();
						var depends = line.substring(target_index + 1).trim().split(/\s+/);
						
						
						if(env.$START == "") {env.$START = target;}
						env.$TARGET[target] = {
								depends  : depends,
								commands : []
							};
					}
					else
					{
						var commands = line.split(/\s+/);
						if     (commands[0] == "include")  {parse(commands[1], env);}
						else if(commands[0] == "-include") {parse(commands[1], env);}
						else
						{
							throw new Error("missing command " + commands[0] + "(" + linenum + ")");
						}
					}
				}
			};
		
		var line = "";
		while(!f.AtEndOfStream)
		{
			linenum += 1;
			var s = f.ReadLine();
			if(line != "") {s = s.replace(/^\s+/, " ");}
			if(s.length > 0 && s.substring(s.length - 1, s.length) == "\\")
			{
				line += s.substring(0, s.length - 1);
			}
			else
			{
				line += s;
				parse_line(line);
				line = "";
			}
		}
		if(line != "") {parse_line();}
	}
	finally
	{
		f.Close();
	}
	
	return(env);
}

function run(env, target)
{
	var p;
	if(!(p = env.$TARGET[target]))
	{
		// "$(TARGET)" expand
		for(var c in env.$TARGET)
		{
			var t = expand(env, c).value;
			if(t == target) {p = env.$TARGET[c]; break;}
			else if(t.substring(0, 1) == ".")
			{
				// ".c.o" format
			}
		}
	}
	
	var t = fs.FileExists(target) ? fs.GetFile(target).DateLastModified : 0;
	if(p)
	{
		var xs   = command_expand(env, p.depends);
		var need = opt.always_make;
		if(xs.length == 0 || t == 0) {need = true;}
		for(var i = 0; i < xs.length; i++)
		{
			if(opt.print) {WScript.Echo(target + " : " + xs[i]);}
			var d = run(env, xs[i]);
			if(t == 0 || t < d) {need = true;}
		}
		if(need)
		{
			if(opt.print) {WScript.Echo(target + " : ");}
			for(var i = 0; i < p.commands.length; i++)
			{
				var cmd = p.commands[i];
				cmd = cmd.replace(/\$[@%<]/,
					function (v)
					{
						if     (v == "$@") {return(target);}
						else if(v == "$%") {return(xs.join(" "));}
						else if(v == "$<") {return(xs[0]);}
						else
						{
							throw new Error("");
						}
					});
				
				exec(expand(env, cmd).value);
			}
			t = fs.FileExists(target) ? fs.GetFile(target).DateLastModified : 0;
		}
	}
	return(t);
}

function expand(env, s, i, quote)
{
	i     = i || 0;
	quote = quote || "";
	
	// $(OUT)
	// $(DEPEND.INC)
	// $(SRCS:%.c=$(WORK)%.obj)
	// $(shell cygpath '$(WINDIR)')
	var r = {value : "", length : 0};
	
	for(; i < s.length; i++)
	{
		var c = s.substring(i, i + 1);
		if(quote != "" && c == quote)
		{
			return(r);
		}
		else if(c == "\"" || c == "'")
		{
			var p = expand(env, s, i + 1, c);
			r.value  += c + p.value + c;
			r.length += p.length + 2;
			i        += p.length + 1;
		}
		else if(c == "$" && s.substring(i + 1, i + 2) == "(")
		{
			var p = expand(env, s, i + 2, ")");
			var re;
			if(re = p.value.match(/^(\w+):/))
			{
				// $(SRCS:%.c=$(WORK)%.obj)
				r.value += "replace";
			}
			else
			{
				var xs = command_split(p.value, " ", 1);
				if(xs.length == 1)
				{
					// $(OUT)
					// $(DEPEND.INC)
					// $("ProgramFiles(x86)")
					r.value += expand(env, env.get_val(p.value.replace(/^(['"])(.*)\1$/, "$2"))).value; // '
				}
				else if(xs[0] == "shell")
				{
					// $(shell cygpath '$(WINDIR)')
					r.value += exec(xs[1], true);
				}
				else if(xs[0] == "subst")
				{
					// $(subst from,to,text)
					var param = command_split(xs[1], ",", 2);
					r.value += expand(env, param[2] || "").value.replace(expand(env, param[0] || "").value, expand(env, param[1] || "").value);
				}
				else if(xs[0] == "patsubst")
				{
					// $(patsubst %.c,%.o,foo.c)
					var param = command_split(xs[1], ",", 2);
					throw new Error("not suported patsubst command [" + s + "]");
				}
				else
				{
					throw new Error("unknown command [" + s + "]");
				}
			}
			r.length += p.length + 3;
			i        += p.length + 2;
		}
		else
		{
			r.value  += c;
			r.length += 1;
		}
	}
	if(quote != "") {throw new Error("bad quote string [" + s + "]");}
	
	return(r);
}

function command_split(s, splitter, maxsplit)
{
	splitter = splitter || " ";
	maxsplit = maxsplit || 0;
	
	var quote   = [];
	var xs      = [];
	var command = "";
	
	for(var i = 0; i < s.length; i++)
	{
		var c = s.substring(i, i + 1);
		if(quote.length == 0 && c == splitter)
		{
			if(command != "")
			{
				xs.push(command);
				if(maxsplit > 0 && maxsplit == xs.length)
				{
					if(i + 1 < s.length) {xs.push(s.substring(i + 1));}
					return(xs);
				}
			}
			command = "";
		}
		else if(quote.length > 0 && c == quote[quote.length - 1])
		{
			command += c;
			quote.pop();
		}
		else
		{
			if(c == "\"" || c == "'")
			{
				quote.push(c);
			}
			else if(c == "(")
			{
				quote.push(")");
			}
			command += c;
		}
	}
	if(quote.length > 0) {throw new Error("quote error [" + s + "]");}
	
	if(command != "") {xs.push(command);}
	
	return(xs);
}

function array_add(xs, p)
{
	if(p instanceof Array)
	{
		for(var i = 0; i < p.length; i++) {array_add(xs, p[i]);}
	}
	else
	{
		xs.push(p);
	}
}

function command_expand(env, c)
{
	if(c instanceof Array)
	{
		var xs = [];
		for(var i = 0; i < c.length; i++)
		{
			array_add(xs, command_expand(env, c[i]));
		}
		return(xs);
	}
	else
	{
		var xs = command_split(expand(env, c).value);
		if(xs.length == 1 && xs[0] == c) {return(xs);}
		return(command_expand(env, xs));
	}
}

function exec(s, subshell)
{
	subshell = subshell || false;
	
	if(s instanceof Array)
	{
		s = s.join(" ");
	}
	
	// -@command
	var no_error = false;
	var no_echo  = false;
	if(s.substring(0, 1) == "-") {s = s.substring(1); no_error = true;}
	if(s.substring(0, 1) == "@") {s = s.substring(1); no_echo  = true;}
	
	if(subshell)
	{
		return(sh.Exec(s).StdOut.ReadAll().trimEnd());
	}
	else
	{
		if(opt.print) {WScript.Echo("    " + s);}
		if(!opt.just_print)
		{
			var p = sh.Exec("cmd /d /c " + s);
			while(!no_echo && !p.StdOut.AtEndOfStream)
			{
				WScript.Echo(p.StdOut.ReadLine());
			}
		}
	}
}