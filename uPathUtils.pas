unit uPathUtils;

{$mode objfpc}{$H+}

// =====================================================================
// uPathUtils — shared path helpers for relative-path management
// =====================================================================
//
// Used by uCutoutAnimator (.action / .anim files) and uSpritePicker
// (.tileset files) to store all file references as paths relative to
// the container file's directory. This makes the whole bundle
// (.action + .anim + .tileset + images) portable: you can move or zip
// the folder and every reference still resolves correctly on load.
//
// All functions are standalone (no class) so they can be called from
// any unit without instantiating an object.

interface

uses
  Classes, SysUtils, LazFileUtils;

// Convert an absolute TargetPath into a path relative to the directory
// of BaseFile. The result uses forward slashes for cross-platform
// portability — a .action / .anim / .tileset file written on Windows
// can be read on Linux without path-separator issues.
//
// Returns '' if TargetPath is ''. Returns '.' if TargetPath resolves
// to the same as BaseFile's directory (rare for files; only matters
// when TargetPath is itself a directory).
//
// LazFileUtils.CreateRelativePath signature:
//   function CreateRelativePath(const Filename, BaseDirectory: string): string;
// Note the parameter order: TARGET first, BASE second. Getting this
// wrong produces ".." for files in the same directory as BaseFile
// (because CreateRelativePath is then asked to make BaseDir relative
// to TargetFull, which is one level up = ".."). The correct call
// passes TargetFull as Filename and BaseDir as BaseDirectory, so
// for files in the same directory CreateRelativePath returns just
// the filename (e.g. "hatchet.tileset").
function MakeRelativePath(const BaseFile, TargetPath: string): string;

// Resolve a relative path stored in a container file (.action / .anim /
// .tileset) against that container file's directory, returning an
// absolute path. Accepts both forward and back slashes (so files are
// portable across OSes).
//
// Legacy support: if RelativePath is ALREADY absolute (e.g. an old
// file written before relative-path support, storing something like
// 'C:\proj\images\foo.png'), we return it as-is via ExpandFileName so
// existing files keep working. Without this guard, we'd prepend
// BaseDir and produce nonsense like
// 'C:\proj\res\C:\proj\images\foo.png'.
//
// Returns '' if RelativePath is ''.
function ResolveRelativePath(const BaseFile, RelativePath: string): string;

implementation

function MakeRelativePath(const BaseFile, TargetPath: string): string;
var
  BaseDir, TargetFull: string;
begin
  if TargetPath = '' then
  begin
    Result := '';
    Exit;
  end;
  BaseDir := ExtractFilePath(BaseFile);
  if BaseDir = '' then
    BaseDir := IncludeTrailingPathDelimiter(GetCurrentDir);
  // Both args MUST be absolute for CreateRelativePath to compare them
  // correctly. ExpandFileName also collapses any "./" or "../" in
  // the input so the comparison is on canonical paths.
  BaseDir := ExpandFileName(BaseDir);
  TargetFull := ExpandFileName(TargetPath);
  // Strip the trailing path delimiter from BaseDir —
  // CreateRelativePath can misbehave on some FPC versions if the
  // base path ends with a delimiter (it treats the trailing slash
  // as part of the directory name when splitting).
  BaseDir := ExcludeTrailingPathDelimiter(BaseDir);
  Result := CreateRelativePath(TargetFull, BaseDir);
  // Normalize to forward slashes for storage portability.
  Result := StringReplace(Result, '\', '/', [rfReplaceAll]);
end;

function ResolveRelativePath(const BaseFile, RelativePath: string): string;
var
  BaseDir, Normalized: string;
begin
  if RelativePath = '' then
  begin
    Result := '';
    Exit;
  end;
  // Convert forward slashes back to native path separators in case the
  // file was written on a different OS.
  Normalized := StringReplace(RelativePath, '/', PathDelim, [rfReplaceAll]);

  // Detect absolute paths:
  //   Unix absolute  -> starts with PathDelim ('/')
  //   Windows drive  -> second char is ':' (e.g. 'C:\...')
  //   UNC             -> starts with '\\' (two PathDelim)
  if (Length(Normalized) >= 1) and (Normalized[1] = PathDelim) then
  begin
    // Unix absolute OR Windows UNC ('\\server\share\...').
    // ExpandFileName canonicalizes without prepending anything.
    Result := ExpandFileName(Normalized);
    Exit;
  end;
  if (Length(Normalized) >= 2) and (Normalized[2] = ':') then
  begin
    // Windows drive-absolute path ('C:\...'). ExpandFileName canonicalizes
    // without prepending anything.
    Result := ExpandFileName(Normalized);
    Exit;
  end;

  // Genuinely relative path — resolve against BaseFile's directory.
  BaseDir := ExtractFilePath(BaseFile);
  if BaseDir = '' then
    BaseDir := IncludeTrailingPathDelimiter(GetCurrentDir);
  Result := ExpandFileName(BaseDir + Normalized);
end;

end.
