//
//  FMXFirstRunViewController.swift
//  Focusmaxxing Hub
//
//  the first run: the five setup steps from the checklist, one screen per step, one big
//  button per screen. steps 1 and 2 happen on the computer and are already done by the
//  time the hub opens, so they show as done. step 3 signs in with the Apple ID, step 4
//  fetches the helper from the App Store and switches it on, step 5 goes to the app list.
//
//  the hub switches the helper on itself through the helper's own "enable" link; the only
//  helper-related tap the customer makes is Apple's "Allow VPN configuration".
//
//  it is the first thing anybody sees of focusmaxxing on a phone, so it is dressed the same as
//  the rest of the product: the mark at the top, the five steps as a row of bars, one sentence
//  large enough to read at arm's length, and one glowing button. FMXTheme holds the colours.
//

import UIKit

extension UserDefaults {
    // set once the five steps have been walked through
    var fmxFirstRunDone: Bool {
        get { self.bool(forKey: "fmxFirstRunDone") }
        set { self.set(newValue, forKey: "fmxFirstRunDone") }
    }
}

final class FMXFirstRunViewController: UIViewController {
    // called after the last step, with the presenting screen expected to show the app list
    var completion: (() -> Void)?

    private struct Step {
        let sentence: String
        let note: String?
    }

    // the five steps, word for word from the checklist
    private let steps: [Step] = [
        Step(sentence: "On your computer, open Focusmaxxing Setup and plug in your phone.", note: nil),
        Step(sentence: "Sign in with your Apple ID. Focusmaxxing Hub appears on your phone.", note: nil),
        Step(sentence: "On your phone, open Focusmaxxing Hub and sign in with the same Apple ID.", note: nil),
        Step(sentence: "Tap \"Get the helper\". The App Store opens; tap Get, come back, tap Allow.",
             note: "You'll see a VPN icon now and then. That's the helper connecting the Hub to your phone; nothing leaves your phone."),
        Step(sentence: "Tap Install on Instagram and YouTube. Done.",
             note: "Focusmaxxing Hub keeps your apps working. If an app ever won't open, open the Hub."),
    ]

    private var index = 0
    private var helperSwitchedOn = false
    private var waitingForHelper = false

    private let markView = UIImageView()
    private let stepLabel = UILabel()
    private let sentenceLabel = UILabel()
    private let noteCard = UIView()
    private let noteLabel = UILabel()
    private let doneRow = UIStackView()
    private let doneMark = UIImageView()
    private let doneLabel = UILabel()
    private let button = FMXPrimaryButton(title: "Next")
    private let bars = UIStackView()

    init() {
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
        self.isModalInPresentation = true
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = FMXTheme.ink

        let backdrop = FMXTheme.backdrop()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(backdrop)

        self.markView.image = UIImage(named: "FMXMark")?.withRenderingMode(.alwaysTemplate)
        self.markView.tintColor = FMXTheme.teal
        self.markView.contentMode = .scaleAspectFit

        // one bar per step, the ones behind you lit
        self.bars.axis = .horizontal
        self.bars.distribution = .fillEqually
        self.bars.spacing = 6
        for _ in self.steps {
            let bar = UIView()
            bar.backgroundColor = FMXTheme.surfaceHigh
            bar.layer.cornerRadius = 2.5
            self.bars.addArrangedSubview(bar)
        }

        self.stepLabel.font = FMXFont.of(13, .bold)
        self.stepLabel.textColor = FMXTheme.faint

        self.sentenceLabel.font = FMXFont.of(28, .heavy)
        self.sentenceLabel.textColor = FMXTheme.text
        self.sentenceLabel.numberOfLines = 0

        self.noteCard.backgroundColor = FMXTheme.card
        self.noteCard.layer.cornerRadius = FMXTheme.radiusSmall
        self.noteCard.layer.borderWidth = 1
        self.noteCard.layer.borderColor = FMXTheme.hairline.cgColor

        self.noteLabel.font = FMXFont.of(14, .regular)
        self.noteLabel.textColor = FMXTheme.muted
        self.noteLabel.numberOfLines = 0
        self.noteLabel.translatesAutoresizingMaskIntoConstraints = false
        self.noteCard.addSubview(self.noteLabel)

        self.doneMark.image = UIImage(systemName: "checkmark.circle.fill")
        self.doneMark.tintColor = FMXTheme.volt
        self.doneMark.contentMode = .scaleAspectFit
        self.doneMark.setContentHuggingPriority(.required, for: .horizontal)

        self.doneLabel.font = FMXFont.of(15, .semibold)
        self.doneLabel.textColor = FMXTheme.accentText
        self.doneLabel.numberOfLines = 0

        self.doneRow.axis = .horizontal
        self.doneRow.alignment = .top
        self.doneRow.spacing = 8
        self.doneRow.addArrangedSubview(self.doneMark)
        self.doneRow.addArrangedSubview(self.doneLabel)

        self.button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)

        let text = UIStackView(arrangedSubviews: [self.stepLabel, self.sentenceLabel, self.noteCard, self.doneRow])
        text.axis = .vertical
        text.spacing = 18
        text.setCustomSpacing(10, after: self.stepLabel)

        for view in [self.markView, self.bars, text, self.button] {
            view.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(view)
        }

        let guide = self.view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: self.view.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            backdrop.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),

            self.markView.topAnchor.constraint(equalTo: guide.topAnchor, constant: 20),
            self.markView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 28),
            self.markView.widthAnchor.constraint(equalToConstant: 38),
            self.markView.heightAnchor.constraint(equalToConstant: 38),

            self.bars.topAnchor.constraint(equalTo: self.markView.bottomAnchor, constant: 28),
            self.bars.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 28),
            self.bars.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -28),
            self.bars.heightAnchor.constraint(equalToConstant: 5),

            text.topAnchor.constraint(equalTo: self.bars.bottomAnchor, constant: 36),
            text.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 28),
            text.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -28),
            // a long sentence wraps rather than sliding under the button
            text.bottomAnchor.constraint(lessThanOrEqualTo: self.button.topAnchor, constant: -20),

            self.noteLabel.topAnchor.constraint(equalTo: self.noteCard.topAnchor, constant: 14),
            self.noteLabel.bottomAnchor.constraint(equalTo: self.noteCard.bottomAnchor, constant: -14),
            self.noteLabel.leadingAnchor.constraint(equalTo: self.noteCard.leadingAnchor, constant: 14),
            self.noteLabel.trailingAnchor.constraint(equalTo: self.noteCard.trailingAnchor, constant: -14),

            self.doneMark.widthAnchor.constraint(equalToConstant: 20),
            self.doneMark.heightAnchor.constraint(equalToConstant: 20),

            self.button.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 28),
            self.button.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -28),
            self.button.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -24),
            self.button.heightAnchor.constraint(equalToConstant: 58),
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(cameBack), name: UIApplication.didBecomeActiveNotification, object: nil)

        self.show(step: 0)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: state

    private var isSignedIn: Bool {
        return DatabaseManager.shared.activeTeam(in: DatabaseManager.shared.viewContext) != nil
    }

    private var isHelperInstalled: Bool {
        guard let url = URL(string: "localdevvpn://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    private func show(step index: Int) {
        self.index = index
        let step = self.steps[index]

        self.stepLabel.text = "Step \(index + 1) of \(self.steps.count)"
        self.sentenceLabel.text = step.sentence
        self.noteLabel.text = step.note
        self.noteCard.isHidden = (step.note == nil)

        for (at, bar) in self.bars.arrangedSubviews.enumerated() {
            bar.backgroundColor = (at <= index) ? FMXTheme.teal : FMXTheme.surfaceHigh
        }

        switch index {
        case 0, 1:
            self.doneLabel.text = "Done. Focusmaxxing Hub is on your phone, so this step is behind you."
            self.doneRow.isHidden = false
            self.button.setTitle("Next", for: .normal)

        case 2:
            if self.isSignedIn {
                self.doneLabel.text = "Signed in."
                self.doneRow.isHidden = false
                self.button.setTitle("Next", for: .normal)
            } else {
                self.doneRow.isHidden = true
                self.button.setTitle("Sign in with Apple ID", for: .normal)
            }

        case 3:
            if self.helperSwitchedOn {
                self.doneLabel.text = "The helper is on."
                self.doneRow.isHidden = false
                self.button.setTitle("Next", for: .normal)
            } else if self.isHelperInstalled {
                self.doneLabel.text = "The helper is installed."
                self.doneRow.isHidden = false
                self.button.setTitle("Switch the helper on", for: .normal)
            } else {
                self.doneRow.isHidden = true
                self.button.setTitle("Get the helper", for: .normal)
            }

        default:
            self.doneRow.isHidden = true
            self.button.setTitle("Open the app list", for: .normal)
        }
    }

    // MARK: the one button

    @objc private func buttonTapped() {
        switch self.index {
        case 0, 1:
            self.show(step: self.index + 1)

        case 2:
            if self.isSignedIn {
                self.show(step: 3)
            } else {
                self.signIn()
            }

        case 3:
            if self.helperSwitchedOn {
                self.show(step: 4)
            } else if self.isHelperInstalled {
                self.switchHelperOn()
            } else {
                self.waitingForHelper = true
                UIApplication.shared.open(FMXLinks.helperAppStoreURL)
            }

        default:
            UserDefaults.standard.fmxFirstRunDone = true
            self.dismiss(animated: true) { [completion] in
                completion?()
            }
        }
    }

    private func signIn() {
        self.button.isEnabled = false
        AppManager.shared.authenticate(presentingViewController: self) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.button.isEnabled = true
                switch result {
                case .failure(let error) where error is CancellationError:
                    // the sign-in may still have gone through before a later check failed; re-read the state
                    self.show(step: 2)
                case .failure(let error):
                    ToastView(error: error).show(in: self)
                    self.show(step: 2)
                case .success:
                    self.show(step: 3)
                }
            }
        }
    }

    // the helper's own link switches it on and it opens the hub again a second later.
    // iOS shows its one-time "Allow VPN configuration" question inside the helper.
    private func switchHelperOn() {
        self.waitingForHelper = true
        UIApplication.shared.open(FMXLinks.helperEnableURL) { [weak self] opened in
            guard opened else { return }
            DispatchQueue.main.async {
                self?.helperSwitchedOn = true
            }
        }
    }

    // back from the App Store or from the helper
    @objc private func cameBack() {
        guard self.index == 3, self.waitingForHelper else { return }
        self.waitingForHelper = false

        if self.helperSwitchedOn {
            self.show(step: 3)
        } else if self.isHelperInstalled {
            // just installed from the App Store: switch it on straight away
            self.switchHelperOn()
        } else {
            self.show(step: 3)
        }
    }
}
