classdef TestFunctionNamesMatchFiles < matlab.unittest.TestCase
    % Every function file must declare the name it is stored under.
    %
    % MATLAB dispatches on the file name, not on the name in the function
    % line, so the two disagreeing is silent. This repository had exactly that:
    % extract_features.m declared itself as extract_features_windowed while
    % holding an older 30-feature implementation, next to the live 42-feature
    % extract_features_windowed.m. Calling extract_features would have run the
    % superseded code under the name of the current code, and the only symptom
    % would have been a feature matrix with the wrong number of columns.
    %
    % A repository-wide check is cheap and stops the class of fault, rather
    % than that one instance of it.

    methods (Test)

        function everyFunctionFileDeclaresItsOwnName(testCase)
            root  = fileparts(fileparts(mfilename("fullpath")));
            files = dir(fullfile(root, "**", "*.m"));

            offenders = strings(0,1);

            for k = 1:numel(files)
                full = fullfile(files(k).folder, files(k).name);
                [~, stem] = fileparts(files(k).name);

                lines = string(splitlines(fileread(full)));
                % First non-blank, non-comment line.
                trimmed = strip(lines);
                idx = find(trimmed ~= "" & ~startsWith(trimmed, "%"), 1);
                if isempty(idx)
                    continue
                end

                first = trimmed(idx);
                if ~startsWith(first, "function")
                    continue    % a script, which has no name to match
                end

                declared = TestFunctionNamesMatchFiles.declaredName(first);
                if declared ~= "" && declared ~= string(stem)
                    rel = erase(string(full), string(root) + filesep);
                    offenders(end+1) = rel + " declares " + declared; %#ok<AGROW>
                end
            end

            testCase.verifyEmpty(offenders, ...
                "function files whose declared name differs from their filename:" + ...
                newline + strjoin(offenders, newline));
        end

    end

    methods (Static)
        function name = declaredName(functionLine)
            % Handles "function out = name(args)", "function [a,b] = name(args)"
            % and "function name(args)".
            rest = strip(extractAfter(functionLine, "function"));
            if contains(rest, "=")
                rest = strip(extractAfter(rest, "="));
            end
            if contains(rest, "(")
                rest = extractBefore(rest, "(");
            end
            name = strip(rest);
        end
    end
end
