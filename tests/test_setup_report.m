function tests = test_setup_report
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.TestData.Path = path;
addpath(fileparts(fileparts(mfilename('fullpath'))));
tc.TestData.Root = tempname; mkdir(tc.TestData.Root);
end

function teardownOnce(tc)
path(tc.TestData.Path);
% Only the temporary test fixture tree created above is removed.
fixture=char(java.io.File(tc.TestData.Root).getCanonicalPath());
temporaryRoot=char(java.io.File(tempdir).getCanonicalPath());
tc.assertTrue(startsWith([fixture filesep],[temporaryRoot filesep], ...
    'IgnoreCase',ispc),'Fixture cleanup must stay under MATLAB tempdir');
rmdir(tc.TestData.Root,'s');
end

function testDuplicateRootsAndInactivePluginFolders(tc)
old = path; cleanup = onCleanup(@()path(old)); %#ok<NASGU>
one=fullfile(tc.TestData.Root,'eeglab_one'); two=fullfile(tc.TestData.Root,'eeglab_two');
mkdir(one); mkdir(two);
writeFixture(fullfile(one,'eeglab.m'),'error(''FixtureMustNotExecute'');');
writeFixture(fullfile(two,'eeglab.m'),'error(''FixtureMustNotExecute'');');
for folder = {'QuickLab0.91','QuickLab_11.12.21_NL'}
    plugin=fullfile(one,'plugins',folder{1}); mkdir(plugin);
    writeFixture(fullfile(plugin,'eegplugin_QuickLab.m'),'error(''PluginMustNotExecute'');');
end
% Plugin folders themselves are not added: duplicates must still be detected.
addpath(two,'-begin'); addpath(one,'-begin');
before=path; folderBefore=pwd;
report=quicklab_setup_report;
tc.verifyEqual(path,before); tc.verifyEqual(pwd,folderBefore);
tc.verifyEqual(report.Functions(1).Files{1},fullfile(one,'eeglab.m'));
tc.verifyTrue(all(ismember({one,two},report.EEGLABRoots)));
tc.verifyTrue(any(contains(report.Issues,'2 plugin files named eegplugin_quicklab.m')));
tc.verifyEqual(sum(report.PluginFolders.EEGLABRoot==string(one)),2);
end

function testOrdinaryReportIsReadOnly(tc)
before=path; folderBefore=pwd; figuresBefore=findall(groot,'Type','figure');
report=quicklab_setup_report;
tc.verifyEqual(path,before); tc.verifyEqual(pwd,folderBefore);
tc.verifyEqual(findall(groot,'Type','figure'),figuresBefore);
tc.verifyTrue(isstruct(report)); tc.verifyTrue(istable(report.PluginFolders));
end

function writeFixture(file,text)
fid=fopen(file,'w'); assert(fid~=-1); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',text);
end
