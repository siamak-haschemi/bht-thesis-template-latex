# latexmk config for the BHT thesis template.
#
# Wires `makeglossaries` into latexmk so the abbreviations list (see
# preamble.tex / abbreviations.tex) is regenerated between pdflatex passes.
# Without this, latexmk does not know about the .acn -> .acr conversion and
# the abbreviations list ends up empty.

add_cus_dep('acn', 'acr', 0, 'makeglossaries');
add_cus_dep('glo', 'gls', 0, 'makeglossaries');

sub makeglossaries {
    my ($base, $path) = fileparse($_[0]);
    pushd $path;
    my $rc = system('makeglossaries', $base);
    popd;
    return $rc;
}

# Make sure `latexmk -c` knows about glossaries artefacts.
push @generated_exts, 'glo', 'gls', 'glg', 'acn', 'acr', 'alg', 'ist', 'xdy';
